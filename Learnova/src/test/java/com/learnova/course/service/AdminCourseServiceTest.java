package com.learnova.course.service;

import com.learnova.course.dto.CategoryCreateRequest;
import com.learnova.course.dto.CourseModerationRequest;
import com.learnova.course.repository.CategoryRepository;
import com.learnova.course.repository.CourseLifecycleRepository;
import com.learnova.enrollment.support.CurrentUserResolver;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminCourseServiceTest {

    @Mock
    private CurrentUserResolver currentUserResolver;

    @Mock
    private CourseLifecycleRepository lifecycleRepository;

    @Mock
    private CategoryRepository categoryRepository;

    @InjectMocks
    private AdminCourseService adminCourseService;

    @Test
    void listCoursesNormalizesStatusFilter() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(3L);

        when(lifecycleRepository.findAdminCourses("PENDING_REVIEW"))
                .thenReturn(java.util.List.of());

        adminCourseService.listCourses("  pending_review  ");

        verify(lifecycleRepository).findAdminCourses("PENDING_REVIEW");
    }

    @Test
    void listCoursesWithoutFilterPassesNull() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(3L);

        adminCourseService.listCourses(null);

        verify(lifecycleRepository).findAdminCourses(null);
    }

    @Test
    void publishCourseUsesActor() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(3L);

        adminCourseService.publishCourse(12L);

        verify(lifecycleRepository).publish(3L, 12L);
    }

    @Test
    void rejectCourseRequiresReason() {
        IllegalArgumentException exception =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> adminCourseService.rejectCourse(
                                12L,
                                new CourseModerationRequest(" ")
                        )
                );

        assertEquals(
                "A rejection reason is required.",
                exception.getMessage()
        );
    }

    @Test
    void createCategoryDelegates() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(3L);

        adminCourseService.createCategory(
                new CategoryCreateRequest("DevOps", "Deployment courses")
        );

        verify(categoryRepository).createCategory(
                3L,
                "DevOps",
                "Deployment courses"
        );
    }

    @Test
    void archiveCourseRequiresValidId() {
        assertThrows(
                IllegalArgumentException.class,
                () -> adminCourseService.archiveCourse(0L)
        );
    }
}
