package com.learnova.course.service;

import com.learnova.course.dto.CataloguePageResponse;
import com.learnova.course.dto.CategoryResponse;
import com.learnova.course.dto.CourseSearchRequest;
import com.learnova.course.repository.CategoryRepository;
import com.learnova.course.repository.CourseRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
public class CourseSearchService {

    private static final int DEFAULT_PAGE_SIZE = 12;
    private static final int MAX_PAGE_SIZE = 50;

    private static final Set<String> ALLOWED_DIFFICULTIES =
            Set.of(
                    "beginner",
                    "intermediate",
                    "advanced"
            );

    private static final Set<String> ALLOWED_SORT_OPTIONS =
            Set.of(
                    "relevance",
                    "rating",
                    "newest",
                    "popular",
                    "title"
            );

    private final CategoryRepository categoryRepository;
    private final CourseRepository courseRepository;

    public CourseSearchService(
            CategoryRepository categoryRepository,
            CourseRepository courseRepository
    ) {
        this.categoryRepository = categoryRepository;
        this.courseRepository = courseRepository;
    }

    public List<CategoryResponse> getActiveCategories() {
        return categoryRepository.findActiveCategories();
    }

    public CataloguePageResponse searchCourses(
            CourseSearchRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Course search request is required."
            );
        }

        String search = normalizeSearch(request.search());
        Long categoryId = validateCategoryId(
                request.categoryId()
        );

        String difficulty = normalizeDifficulty(
                request.difficulty()
        );

        String sort = normalizeSort(request.sort());

        int page = validatePage(request.page());
        int size = validateSize(request.size());

        int offset = calculateOffset(page, size);

        CourseRepository.SearchResult result =
                courseRepository.search(
                        search,
                        categoryId,
                        difficulty,
                        sort,
                        size,
                        offset
                );

        long totalPages = calculateTotalPages(
                result.totalElements(),
                size
        );

        boolean first = page == 0;

        boolean last = totalPages == 0
                || page >= totalPages - 1;

        return new CataloguePageResponse(
                result.content(),
                page,
                size,
                result.totalElements(),
                totalPages,
                first,
                last
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

        String normalizedDifficulty = difficulty
                .strip()
                .toLowerCase(Locale.ROOT);

        if (!ALLOWED_DIFFICULTIES.contains(
                normalizedDifficulty
        )) {
            throw new IllegalArgumentException(
                    "difficulty must be beginner, "
                            + "intermediate, or advanced."
            );
        }

        /*
         * PostgreSQL stores difficulty values in uppercase.
         * The database function also normalizes the parameter,
         * but passing an uppercase value keeps the boundary clear.
         */
        return normalizedDifficulty.toUpperCase(Locale.ROOT);
    }

    private String normalizeSort(String sort) {
        if (sort == null || sort.isBlank()) {
            return "relevance";
        }

        String normalizedSort = sort
                .strip()
                .toLowerCase(Locale.ROOT);

        if (!ALLOWED_SORT_OPTIONS.contains(normalizedSort)) {
            throw new IllegalArgumentException(
                    "sort must be relevance, rating, "
                            + "newest, popular, or title."
            );
        }

        return normalizedSort;
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
        /*
         * This also protects against someone constructing the DTO
         * manually without using the controller's default value.
         */
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

        /*
         * PostgreSQL's p_offset parameter is INTEGER.
         */
        if (offset > Integer.MAX_VALUE) {
            throw new IllegalArgumentException(
                    "The requested page is too large."
            );
        }

        return (int) offset;
    }

    private long calculateTotalPages(
            long totalElements,
            int size
    ) {
        if (totalElements == 0) {
            return 0;
        }

        long fullPages = totalElements / size;
        long remainingElements = totalElements % size;

        return remainingElements == 0
                ? fullPages
                : fullPages + 1;
    }
}