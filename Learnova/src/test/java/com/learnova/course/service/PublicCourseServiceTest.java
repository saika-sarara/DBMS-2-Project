package com.learnova.course.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.common.exception.ResourceNotFoundException;
import com.learnova.course.dto.CourseDetailsResponse;
import com.learnova.course.dto.CourseSearchRequest;
import com.learnova.course.dto.PersonalizedCourseCardResponse;
import com.learnova.course.dto.PersonalizedCataloguePageResponse;
import com.learnova.course.repository.CourseReadRepository;
import com.learnova.enrollment.support.CurrentUserResolver;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataAccessException;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PublicCourseServiceTest {

    @Mock
    private CurrentUserResolver currentUserResolver;

    @Mock
    private CourseReadRepository courseReadRepository;

    @InjectMocks
    private PublicCourseService publicCourseService;

    @Test
    void searchCoursesIsAnonymousSafeAndBuildsPage() {
        PersonalizedCourseCardResponse course =
                new PersonalizedCourseCardResponse(
                        1L,
                        "Database Fundamentals",
                        "database-fundamentals-1",
                        "Learn database basics.",
                        null,
                        "beginner",
                        2L,
                        "Database",
                        new BigDecimal("4.50"),
                        10,
                        8,
                        240,
                        3L,
                        "David Miller",
                        "login_required",
                        true,
                        false,
                        false,
                        "Log in to enroll in this course.",
                        0.75
                );

        when(currentUserResolver.getCurrentUserIdOrNull())
                .thenReturn(null);

        when(courseReadRepository.search(
                null,
                "database",
                2L,
                "BEGINNER",
                "rating",
                12,
                12
        )).thenReturn(
                new CourseReadRepository.SearchResult(
                        List.of(course),
                        13L
                )
        );

        CourseSearchRequest request =
                new CourseSearchRequest(
                        "  database  ",
                        2L,
                        "Beginner",
                        "RATING",
                        1,
                        12
                );

        PersonalizedCataloguePageResponse response =
                publicCourseService.searchCourses(request);

        assertEquals(1, response.page());
        assertEquals(12, response.size());
        assertEquals(13L, response.totalElements());
        assertEquals(2L, response.totalPages());
        assertFalse(response.first());
        assertTrue(response.last());
        assertEquals("login_required", response.content().get(0).cardStatus());

        verify(courseReadRepository).search(
                null,
                "database",
                2L,
                "BEGINNER",
                "rating",
                12,
                12
        );
    }

    @Test
    void searchCoursesRejectsInvalidDifficulty() {
        CourseSearchRequest request =
                new CourseSearchRequest(
                        null,
                        null,
                        "expert",
                        "relevance",
                        0,
                        12
                );

        IllegalArgumentException exception =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> publicCourseService.searchCourses(request)
                );

        assertEquals(
                "difficulty must be beginner, "
                        + "intermediate, or advanced.",
                exception.getMessage()
        );
    }

    @Test
    void getCourseDetailThrowsNotFoundWhenDatabaseReturnsNothing() {
        when(currentUserResolver.getCurrentUserIdOrNull())
                .thenReturn(null);

        when(courseReadRepository.findCourseDetail(null, 99L))
                .thenReturn(null);

        assertThrows(
                ResourceNotFoundException.class,
                () -> publicCourseService.getCourseDetail(99L)
        );
    }

    @Test
    void getLessonContentTranslatesDatabaseErrors() {
        when(currentUserResolver.getCurrentUserIdOrNull())
                .thenReturn(1L);

        when(courseReadRepository.findLessonContent(1L, 7L))
                .thenThrow(new DataAccessException(
                        "nested",
                        new SQLException("You do not have access.", "LTC12")
                ) {
                });

        DatabaseException exception = assertThrows(
                DatabaseException.class,
                () -> publicCourseService.getLessonContent(7L)
        );

        assertEquals("LTC12", exception.getSqlState());
        assertEquals("You do not have access.", exception.getMessage());
    }

    @Test
    void getCourseDetailReturnsDetails() {
        when(currentUserResolver.getCurrentUserIdOrNull())
                .thenReturn(null);

        when(courseReadRepository.findCourseDetail(null, 1L))
                .thenReturn(new CourseDetailsResponse(
                        1L,
                        "Database Fundamentals",
                        "database-fundamentals-1",
                        "Learn database basics.",
                        "Full description.",
                        "beginner",
                        null,
                        2L,
                        "Database",
                        3L,
                        "David Miller",
                        new BigDecimal("4.50"),
                        10,
                        8,
                        240,
                        2L,
                        null,
                        null,
                        "available",
                        false,
                        false,
                        false,
                        null,
                        List.of()
                ));

        CourseDetailsResponse response =
                publicCourseService.getCourseDetail(1L);

        assertEquals("Database Fundamentals", response.title());
        assertFalse(response.locked());
    }
}
