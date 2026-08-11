package com.learnova.course.controller;

import com.learnova.course.dto.PersonalizedCataloguePageResponse;
import com.learnova.course.dto.CategoryResponse;
import com.learnova.course.dto.CourseSearchRequest;
import com.learnova.course.service.PublicCourseService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class CourseControllerTest {

    private PublicCourseService courseSearchService;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        courseSearchService = mock(PublicCourseService.class);

        CourseController courseController =
                new CourseController(courseSearchService);

        mockMvc = MockMvcBuilders
                .standaloneSetup(courseController)
                .build();
    }

    @Test
    void categoriesEndpointReturnsActiveCategories() throws Exception {
        List<CategoryResponse> categories = List.of(
                new CategoryResponse(
                        1L,
                        "Database",
                        "Database and SQL courses"
                )
        );

        when(courseSearchService.getActiveCategories())
                .thenReturn(categories);

        mockMvc.perform(
                        get("/api/v1/catalogue/categories")
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].name").value("Database"))
                .andExpect(
                        jsonPath("$[0].description")
                                .value("Database and SQL courses")
                );
    }

    @Test
    void coursesEndpointReturnsPageResponse() throws Exception {
        PersonalizedCataloguePageResponse response =
                        new PersonalizedCataloguePageResponse(
                        List.of(),
                        0,
                        12,
                        0L,
                        0L,
                        true,
                        true
                );

        when(courseSearchService.searchCourses(
                any(CourseSearchRequest.class)
        )).thenReturn(response);

        mockMvc.perform(
                        get("/api/v1/catalogue/courses")
                                .param("page", "0")
                                .param("size", "12")
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray())
                .andExpect(jsonPath("$.content.length()").value(0))
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(12))
                .andExpect(jsonPath("$.totalElements").value(0))
                .andExpect(jsonPath("$.totalPages").value(0))
                .andExpect(jsonPath("$.first").value(true))
                .andExpect(jsonPath("$.last").value(true));
    }

    @Test
    void invalidCatalogueRequestReturnsBadRequest()
            throws Exception {

        when(courseSearchService.searchCourses(
                any(CourseSearchRequest.class)
        )).thenThrow(
                new IllegalArgumentException(
                        "size must be between 1 and 50."
                )
        );

        mockMvc.perform(
                        get("/api/v1/catalogue/courses")
                                .param("size", "100")
                )
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.error").value("Bad Request"))
                .andExpect(
                        jsonPath("$.message")
                                .value("size must be between 1 and 50.")
                )
                .andExpect(
                        jsonPath("$.path")
                                .value("/api/v1/catalogue/courses")
                );
    }

    @Test
    void nonNumericPageReturnsBadRequest() throws Exception {
        mockMvc.perform(
                        get("/api/v1/catalogue/courses")
                                .param("page", "abc")
                )
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.error").value("Bad Request"))
                .andExpect(jsonPath("$.message").exists())
                .andExpect(
                        jsonPath("$.path")
                                .value("/api/v1/catalogue/courses")
                );
    }

    @Test
    void nonNumericCategoryIdReturnsBadRequest()
            throws Exception {

        mockMvc.perform(
                        get("/api/v1/catalogue/courses")
                                .param("categoryId", "database")
                )
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.error").value("Bad Request"))
                .andExpect(jsonPath("$.message").exists())
                .andExpect(
                        jsonPath("$.path")
                                .value("/api/v1/catalogue/courses")
                );
    }
}
