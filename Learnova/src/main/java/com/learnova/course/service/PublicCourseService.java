package com.learnova.course.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.common.exception.ResourceNotFoundException;
import com.learnova.course.dto.CategoryResponse;
import com.learnova.course.dto.CourseDetailsResponse;
import com.learnova.course.dto.CourseSearchRequest;
import com.learnova.course.dto.CourseSyllabusResponse;
import com.learnova.course.dto.LessonContentBlockResponse;
import com.learnova.course.dto.PersonalizedCataloguePageResponse;
import com.learnova.course.repository.CategoryRepository;
import com.learnova.course.repository.CourseReadRepository;
import com.learnova.enrollment.support.CurrentUserResolver;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
public class PublicCourseService {

    private static final int DEFAULT_PAGE_SIZE = 12;
    private static final int MAX_PAGE_SIZE = 50;

    private static final Set<String> ALLOWED_DIFFICULTIES =
            Set.of("beginner", "intermediate", "advanced");

    private static final Set<String> ALLOWED_SORT_OPTIONS =
            Set.of("relevance", "rating", "newest", "title", "popular");

    private final CurrentUserResolver currentUserResolver;
    private final CourseReadRepository courseReadRepository;
    private final CategoryRepository categoryRepository;

    public PublicCourseService(
            CurrentUserResolver currentUserResolver,
            CourseReadRepository courseReadRepository,
            CategoryRepository categoryRepository
    ) {
        this.currentUserResolver = currentUserResolver;
        this.courseReadRepository = courseReadRepository;
        this.categoryRepository = categoryRepository;
    }

    public List<CategoryResponse> getActiveCategories() {
        try {
            return categoryRepository.findActiveCategories();
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public PersonalizedCataloguePageResponse searchCourses(
            CourseSearchRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Course search request is required."
            );
        }

        String search = normalizeSearch(request.search());
        Long categoryId = validateCategoryId(request.categoryId());
        String difficulty = normalizeDifficulty(request.difficulty());
        String sort = normalizeSort(request.sort());
        int page = validatePage(request.page());
        int size = validateSize(request.size());
        int offset = calculateOffset(page, size);

        Long studentId = currentUserResolver.getCurrentUserIdOrNull();

        try {
            CourseReadRepository.SearchResult result =
                    courseReadRepository.search(
                            studentId,
                            search,
                            categoryId,
                            difficulty,
                            sort,
                            size,
                            offset
                    );

            return toPage(result, page, size);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseDetailsResponse getCourseDetail(Long courseId) {
        if (courseId == null || courseId < 1) {
            throw new IllegalArgumentException(
                    "A valid course id is required."
            );
        }

        Long studentId = currentUserResolver.getCurrentUserIdOrNull();

        try {
            CourseDetailsResponse detail =
                    courseReadRepository.findCourseDetail(
                            studentId,
                            courseId
                    );

            if (detail == null) {
                throw new ResourceNotFoundException(
                        "Course not found or not visible to you."
                );
            }

            return detail;
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseSyllabusResponse getCourseSyllabus(Long courseId) {
        if (courseId == null || courseId < 1) {
            throw new IllegalArgumentException(
                    "A valid course id is required."
            );
        }

        Long studentId = currentUserResolver.getCurrentUserIdOrNull();

        try {
            return courseReadRepository.findCourseSyllabus(
                    studentId,
                    courseId
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public List<LessonContentBlockResponse> getLessonContent(Long lessonId) {
        if (lessonId == null || lessonId < 1) {
            throw new IllegalArgumentException(
                    "A valid lesson id is required."
            );
        }

        Long studentId = currentUserResolver.getCurrentUserIdOrNull();

        try {
            return courseReadRepository.findLessonContent(
                    studentId,
                    lessonId
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    private PersonalizedCataloguePageResponse toPage(
            CourseReadRepository.SearchResult result,
            int page,
            int size
    ) {
        long totalPages = calculateTotalPages(
                result.totalElements(),
                size
        );

        return new PersonalizedCataloguePageResponse(
                result.content(),
                page,
                size,
                result.totalElements(),
                totalPages,
                page == 0,
                totalPages == 0 || page >= totalPages - 1
        );
    }

    private String normalizeSearch(String search) {
        if (search == null || search.isBlank()) {
            return null;
        }
        return search.strip();
    }

    private Long validateCategoryId(Long categoryId) {
        if (categoryId == null) {
            return null;
        }
        if (categoryId < 1) {
            throw new IllegalArgumentException(
                    "categoryId must be greater than 0."
            );
        }
        return categoryId;
    }

    private String normalizeDifficulty(String difficulty) {
        if (difficulty == null || difficulty.isBlank()) {
            return null;
        }

        String normalized = difficulty
                .strip()
                .toLowerCase(Locale.ROOT);

        if (!ALLOWED_DIFFICULTIES.contains(normalized)) {
            throw new IllegalArgumentException(
                    "difficulty must be beginner, "
                            + "intermediate, or advanced."
            );
        }

        return normalized.toUpperCase(Locale.ROOT);
    }

    private String normalizeSort(String sort) {
        if (sort == null || sort.isBlank()) {
            return "relevance";
        }

        String normalized = sort
                .strip()
                .toLowerCase(Locale.ROOT);

        if (!ALLOWED_SORT_OPTIONS.contains(normalized)) {
            throw new IllegalArgumentException(
                    "sort must be relevance, rating, "
                            + "newest, popular, or title."
            );
        }

        return normalized;
    }

    private int validatePage(int page) {
        if (page < 0) {
            throw new IllegalArgumentException(
                    "page must be 0 or greater."
            );
        }
        return page;
    }

    private int validateSize(int size) {
        if (size == 0) {
            return DEFAULT_PAGE_SIZE;
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw new IllegalArgumentException(
                    "size must be between 1 and 50."
            );
        }
        return size;
    }

    private int calculateOffset(int page, int size) {
        long offset = (long) page * size;

        if (offset > Integer.MAX_VALUE) {
            throw new IllegalArgumentException(
                    "The requested page is too large."
            );
        }

        return (int) offset;
    }

    private long calculateTotalPages(long totalElements, int size) {
        if (totalElements == 0) {
            return 0;
        }
        long fullPages = totalElements / size;
        long remaining = totalElements % size;
        return remaining == 0 ? fullPages : fullPages + 1;
    }
}
