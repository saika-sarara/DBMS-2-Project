package com.learnova.course.controller;

import com.learnova.common.exception.GlobalExceptionHandler;
import com.learnova.common.exception.ResourceNotFoundException;
import com.learnova.course.dto.CourseDetailsResponse;
import com.learnova.course.dto.CourseSyllabusResponse;
import com.learnova.course.dto.LessonContentBlockResponse;
import com.learnova.course.dto.PersonalizedCataloguePageResponse;
import com.learnova.course.service.PublicCourseService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PublicCourseControllerTest {

    private PublicCourseService publicCourseService;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        publicCourseService = mock(PublicCourseService.class);

        PublicCourseController controller =
                new PublicCourseController(publicCourseService);

        mockMvc = MockMvcBuilders
                .standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void coursesEndpointReturnsPersonalizedPage() throws Exception {
        when(publicCourseService.searchCourses(
                any()
        )).thenReturn(new PersonalizedCataloguePageResponse(
                List.of(),
                0,
                12,
                0L,
                0L,
                true,
                true
        ));

        mockMvc.perform(get("/api/v1/courses"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray())
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void courseDetailEndpointReturnsDetails() throws Exception {
        when(publicCourseService.getCourseDetail(1L))
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
                        new java.math.BigDecimal("4.50"),
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

        mockMvc.perform(get("/api/v1/courses/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.courseId").value(1))
                .andExpect(jsonPath("$.title").value("Database Fundamentals"))
                .andExpect(jsonPath("$.cardStatus").value("available"));
    }

    @Test
    void courseDetailEndpointReturns404ForHiddenCourse() throws Exception {
        when(publicCourseService.getCourseDetail(99L))
                .thenThrow(new ResourceNotFoundException(
                        "Course not found or not visible to you."
                ));

        mockMvc.perform(get("/api/v1/courses/99"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.message")
                        .value("Course not found or not visible to you."));
    }

    @Test
    void syllabusEndpointReturnsModules() throws Exception {
        when(publicCourseService.getCourseSyllabus(1L))
                .thenReturn(new CourseSyllabusResponse(List.of()));

        mockMvc.perform(get("/api/v1/courses/1/syllabus"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.modules").isArray());
    }

    @Test
    void lessonContentEndpointReturnsBlocks() throws Exception {
        when(publicCourseService.getLessonContent(7L))
                .thenReturn(List.of(
                        new LessonContentBlockResponse(
                                1L,
                                7L,
                                "markdown",
                                "Intro",
                                "# Hello",
                                null,
                                1
                        )
                ));

        mockMvc.perform(get("/api/v1/lessons/7/content"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].blockType").value("markdown"))
                .andExpect(jsonPath("$[0].bodyMarkdown").value("# Hello"));
    }
}
