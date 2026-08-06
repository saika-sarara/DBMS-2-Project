package com.learnova.course.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.course.dto.AdminCategoryResponse;
import com.learnova.course.dto.AdminCourseResponse;
import com.learnova.course.dto.CategoryCreateRequest;
import com.learnova.course.dto.CategoryUpdateRequest;
import com.learnova.course.dto.CourseLifecycleResponse;
import com.learnova.course.dto.CourseModerationRequest;
import com.learnova.course.repository.CategoryRepository;
import com.learnova.course.repository.CourseLifecycleRepository;
import com.learnova.enrollment.support.CurrentUserResolver;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AdminCourseService {

    private final CurrentUserResolver currentUserResolver;
    private final CourseLifecycleRepository lifecycleRepository;
    private final CategoryRepository categoryRepository;

    public AdminCourseService(
            CurrentUserResolver currentUserResolver,
            CourseLifecycleRepository lifecycleRepository,
            CategoryRepository categoryRepository
    ) {
        this.currentUserResolver = currentUserResolver;
        this.lifecycleRepository = lifecycleRepository;
        this.categoryRepository = categoryRepository;
    }

    public List<AdminCourseResponse> listCourses(String statusFilter) {
        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.findAdminCourses(
                    normalizeStatusFilter(statusFilter)
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseLifecycleResponse publishCourse(Long courseId) {
        requireCourseId(courseId);
        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.publish(actorId, courseId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseLifecycleResponse rejectCourse(
            Long courseId,
            CourseModerationRequest request
    ) {
        requireCourseId(courseId);

        if (request == null || request.reason() == null
                || request.reason().isBlank()) {
            throw new IllegalArgumentException(
                    "A rejection reason is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.reject(
                    actorId,
                    courseId,
                    request.reason().strip()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseLifecycleResponse archiveCourse(Long courseId) {
        requireCourseId(courseId);
        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.archive(actorId, courseId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public List<AdminCategoryResponse> listCategories() {
        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return categoryRepository.findAllCategories();
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public AdminCategoryResponse createCategory(
            CategoryCreateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Category data is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return categoryRepository.createCategory(
                    actorId,
                    request.name(),
                    request.description()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public AdminCategoryResponse updateCategory(
            Long categoryId,
            CategoryUpdateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Category data is required."
            );
        }
        if (categoryId == null || categoryId < 1) {
            throw new IllegalArgumentException(
                    "A valid category id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return categoryRepository.updateCategory(
                    actorId,
                    categoryId,
                    request.name(),
                    request.description(),
                    request.isActive()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public void deleteCategory(Long categoryId) {
        if (categoryId == null || categoryId < 1) {
            throw new IllegalArgumentException(
                    "A valid category id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            categoryRepository.deleteCategory(actorId, categoryId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    private String normalizeStatusFilter(String statusFilter) {
        if (statusFilter == null || statusFilter.isBlank()) {
            return null;
        }
        return statusFilter.strip().toUpperCase();
    }

    private void requireCourseId(Long courseId) {
        if (courseId == null || courseId < 1) {
            throw new IllegalArgumentException(
                    "A valid course id is required."
            );
        }
    }
}
