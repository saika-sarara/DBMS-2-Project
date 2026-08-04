package com.learnova.course.service;

import com.learnova.course.dto.CataloguePageResponse;
import com.learnova.course.dto.CourseCardResponse;
import com.learnova.course.dto.CourseSearchRequest;
import com.learnova.course.repository.CategoryRepository;
import com.learnova.course.repository.CourseRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CourseSearchServiceTest {

    @Mock
    private CategoryRepository categoryRepository;

    @Mock
    private CourseRepository courseRepository;

    @InjectMocks
    private CourseSearchService courseSearchService;

    @Test
    void searchCoursesNormalizesParametersAndBuildsPage() {
        CourseCardResponse course =
                new CourseCardResponse(
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
                        OffsetDateTime.parse(
                                "2026-08-04T16:00:00Z"
                        ),
                        0.75
                );

        CourseRepository.SearchResult repositoryResult =
                new CourseRepository.SearchResult(
                        List.of(course),
                        13L
                );

        when(courseRepository.search(
                "database",
                2L,
                "BEGINNER",
                "rating",
                12,
                12
        )).thenReturn(repositoryResult);

        CourseSearchRequest request =
                new CourseSearchRequest(
                        "  database  ",
                        2L,
                        "Beginner",
                        "RATING",
                        1,
                        12
                );

        CataloguePageResponse response =
                courseSearchService.searchCourses(request);

        assertEquals(1, response.page());
        assertEquals(12, response.size());
        assertEquals(13L, response.totalElements());
        assertEquals(2L, response.totalPages());
        assertFalse(response.first());
        assertTrue(response.last());
        assertEquals(1, response.content().size());

        verify(courseRepository).search(
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
                        () -> courseSearchService.searchCourses(request)
                );

        assertEquals(
                "difficulty must be beginner, "
                        + "intermediate, or advanced.",
                exception.getMessage()
        );
    }

    @Test
    void searchCoursesRejectsInvalidSize() {
        CourseSearchRequest request =
                new CourseSearchRequest(
                        null,
                        null,
                        null,
                        "relevance",
                        0,
                        100
                );

        IllegalArgumentException exception =
                assertThrows(
                        IllegalArgumentException.class,
                        () -> courseSearchService.searchCourses(request)
                );

        assertEquals(
                "size must be between 1 and 50.",
                exception.getMessage()
        );
    }

    @Test
    void emptyResultCreatesEmptyPage() {
        when(courseRepository.search(
                null,
                null,
                null,
                "relevance",
                12,
                0
        )).thenReturn(
                new CourseRepository.SearchResult(
                        List.of(),
                        0
                )
        );

        CourseSearchRequest request =
                new CourseSearchRequest(
                        " ",
                        null,
                        "",
                        "",
                        0,
                        12
                );

        CataloguePageResponse response =
                courseSearchService.searchCourses(request);

        assertTrue(response.content().isEmpty());
        assertEquals(0L, response.totalElements());
        assertEquals(0L, response.totalPages());
        assertTrue(response.first());
        assertTrue(response.last());
    }
}
