package com.learnova.course.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.course.dto.ContentBlockCreateRequest;
import com.learnova.course.dto.ContentBlockResponse;
import com.learnova.course.dto.ContentBlockUpdateRequest;
import com.learnova.course.dto.CourseCreateRequest;
import com.learnova.course.dto.CourseLifecycleResponse;
import com.learnova.course.dto.CourseUpdateRequest;
import com.learnova.course.dto.InstructorCourseResponse;
import com.learnova.course.dto.LessonCreateRequest;
import com.learnova.course.dto.LessonResponse;
import com.learnova.course.dto.LessonUpdateRequest;
import com.learnova.course.dto.ModuleCreateRequest;
import com.learnova.course.dto.ModuleResponse;
import com.learnova.course.dto.ModuleUpdateRequest;
import com.learnova.course.repository.CourseContentRepository;
import com.learnova.course.repository.CourseLifecycleRepository;
import com.learnova.enrollment.support.CurrentUserResolver;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class InstructorCourseService {

    private final CurrentUserResolver currentUserResolver;
    private final CourseLifecycleRepository lifecycleRepository;
    private final CourseContentRepository contentRepository;

    public InstructorCourseService(
            CurrentUserResolver currentUserResolver,
            CourseLifecycleRepository lifecycleRepository,
            CourseContentRepository contentRepository
    ) {
        this.currentUserResolver = currentUserResolver;
        this.lifecycleRepository = lifecycleRepository;
        this.contentRepository = contentRepository;
    }

    public List<InstructorCourseResponse> listMyCourses() {
        Long instructorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.findInstructorCourses(instructorId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseLifecycleResponse createCourse(CourseCreateRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Course data is required.");
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.createDraft(
                    actorId,
                    request.categoryId(),
                    request.title(),
                    request.shortDescription(),
                    request.description(),
                    request.difficulty(),
                    request.thumbnailUrl()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseLifecycleResponse updateCourse(
            Long courseId,
            CourseUpdateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException("Course data is required.");
        }
        if (courseId == null || courseId < 1) {
            throw new IllegalArgumentException(
                    "A valid course id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.updateBasicInfo(
                    actorId,
                    courseId,
                    request.categoryId(),
                    request.title(),
                    request.shortDescription(),
                    request.description(),
                    request.difficulty(),
                    request.thumbnailUrl()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseLifecycleResponse submitForReview(Long courseId) {
        if (courseId == null || courseId < 1) {
            throw new IllegalArgumentException(
                    "A valid course id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.submitForReview(actorId, courseId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public CourseLifecycleResponse deleteCourse(Long courseId) {
        if (courseId == null || courseId < 1) {
            throw new IllegalArgumentException(
                    "A valid course id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return lifecycleRepository.deleteCourse(actorId, courseId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public ModuleResponse createModule(
            Long courseId,
            ModuleCreateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException("Module data is required.");
        }
        if (courseId == null || courseId < 1) {
            throw new IllegalArgumentException(
                    "A valid course id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return contentRepository.createModule(
                    actorId,
                    courseId,
                    request.title(),
                    request.description(),
                    request.sequenceOrder()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public ModuleResponse updateModule(
            Long moduleId,
            ModuleUpdateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException("Module data is required.");
        }
        if (moduleId == null || moduleId < 1) {
            throw new IllegalArgumentException(
                    "A valid module id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return contentRepository.updateModule(
                    actorId,
                    moduleId,
                    request.title(),
                    request.description(),
                    request.sequenceOrder()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public void deleteModule(Long moduleId) {
        if (moduleId == null || moduleId < 1) {
            throw new IllegalArgumentException(
                    "A valid module id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            contentRepository.deleteModule(actorId, moduleId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public LessonResponse createLesson(
            Long moduleId,
            LessonCreateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException("Lesson data is required.");
        }
        if (moduleId == null || moduleId < 1) {
            throw new IllegalArgumentException(
                    "A valid module id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return contentRepository.createLesson(
                    actorId,
                    moduleId,
                    request.title(),
                    request.description(),
                    request.sequenceOrder(),
                    request.estimatedDurationMinutes(),
                    request.isPreview()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public LessonResponse updateLesson(
            Long lessonId,
            LessonUpdateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException("Lesson data is required.");
        }
        if (lessonId == null || lessonId < 1) {
            throw new IllegalArgumentException(
                    "A valid lesson id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return contentRepository.updateLesson(
                    actorId,
                    lessonId,
                    request.title(),
                    request.description(),
                    request.sequenceOrder(),
                    request.estimatedDurationMinutes(),
                    request.isPreview()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public void deleteLesson(Long lessonId) {
        if (lessonId == null || lessonId < 1) {
            throw new IllegalArgumentException(
                    "A valid lesson id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            contentRepository.deleteLesson(actorId, lessonId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public ContentBlockResponse createBlock(
            Long lessonId,
            ContentBlockCreateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Content block data is required."
            );
        }
        if (lessonId == null || lessonId < 1) {
            throw new IllegalArgumentException(
                    "A valid lesson id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return contentRepository.createBlock(
                    actorId,
                    lessonId,
                    request.blockType(),
                    request.title(),
                    request.bodyMarkdown(),
                    request.resourceUrl(),
                    request.sequenceOrder()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public ContentBlockResponse updateBlock(
            Long blockId,
            ContentBlockUpdateRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException(
                    "Content block data is required."
            );
        }
        if (blockId == null || blockId < 1) {
            throw new IllegalArgumentException(
                    "A valid content block id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            return contentRepository.updateBlock(
                    actorId,
                    blockId,
                    request.title(),
                    request.bodyMarkdown(),
                    request.resourceUrl(),
                    request.sequenceOrder()
            );
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }

    public void deleteBlock(Long blockId) {
        if (blockId == null || blockId < 1) {
            throw new IllegalArgumentException(
                    "A valid content block id is required."
            );
        }

        Long actorId = currentUserResolver.getCurrentUserId();

        try {
            contentRepository.deleteBlock(actorId, blockId);
        } catch (DataAccessException ex) {
            throw DatabaseException.from(ex);
        }
    }
}
