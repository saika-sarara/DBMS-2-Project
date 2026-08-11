package com.learnova.course.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.course.dto.CourseCreateRequest;
import com.learnova.course.dto.CourseLifecycleResponse;
import com.learnova.course.dto.CourseUpdateRequest;
import com.learnova.course.dto.ModuleCreateRequest;
import com.learnova.course.dto.ModuleResponse;
import com.learnova.course.repository.CourseContentRepository;
import com.learnova.course.repository.CourseLifecycleRepository;
import com.learnova.enrollment.support.CurrentUserResolver;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataAccessException;

import java.sql.SQLException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class InstructorCourseServiceTest {

    @Mock
    private CurrentUserResolver currentUserResolver;

    @Mock
    private CourseLifecycleRepository lifecycleRepository;

    @Mock
    private CourseContentRepository contentRepository;

    @InjectMocks
    private InstructorCourseService instructorCourseService;

    @Test
    void createCoursePassesActorAndRequestThrough() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(2L);

        CourseLifecycleResponse expected =
                new CourseLifecycleResponse(
                        10L,
                        "New Course",
                        "new-course",
                        "DRAFT",
                        null,
                        null,
                        null,
                        null
                );

        when(lifecycleRepository.createDraft(
                2L,
                1L,
                "New Course",
                "Short",
                "Long",
                "beginner",
                null
        )).thenReturn(expected);

        CourseLifecycleResponse response =
                instructorCourseService.createCourse(
                        new CourseCreateRequest(
                                1L,
                                "New Course",
                                "Short",
                                "Long",
                                "beginner",
                                null
                        )
                );

        assertEquals(10L, response.courseId());
        assertEquals("DRAFT", response.status());

        verify(lifecycleRepository).createDraft(
                2L,
                1L,
                "New Course",
                "Short",
                "Long",
                "beginner",
                null
        );
    }

    @Test
    void createModuleTranslatesDatabaseErrors() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(2L);

        when(contentRepository.createModule(
                2L,
                10L,
                "Intro",
                null,
                null
        )).thenThrow(new DataAccessException(
                "nested",
                new SQLException(
                        "You can only manage your own courses.",
                        "LTC10"
                )
        ) {
        });

        DatabaseException exception = assertThrows(
                DatabaseException.class,
                () -> instructorCourseService.createModule(
                        10L,
                        new ModuleCreateRequest("Intro", null, null)
                )
        );

        assertEquals("LTC10", exception.getSqlState());
    }

    @Test
    void submitForReviewUsesCurrentUser() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(2L);

        instructorCourseService.submitForReview(10L);

        verify(lifecycleRepository).submitForReview(2L, 10L);
    }

    @Test
    void createCourseRequiresRequest() {
        assertThrows(
                IllegalArgumentException.class,
                () -> instructorCourseService.createCourse(null)
        );
    }

    @Test
    void updateCourseRequiresValidId() {
        assertThrows(
                IllegalArgumentException.class,
                () -> instructorCourseService.updateCourse(
                        0L,
                        new CourseUpdateRequest(
                                null,
                                "T",
                                null,
                                null,
                                null,
                                null
                        )
                )
        );
    }

    @Test
    void deleteModuleDelegates() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(2L);

        instructorCourseService.deleteModule(5L);

        verify(contentRepository).deleteModule(2L, 5L);
    }
}
