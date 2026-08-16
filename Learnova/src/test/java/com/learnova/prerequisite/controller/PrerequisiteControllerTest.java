package com.learnova.prerequisite.controller;

import com.learnova.common.exception.GlobalExceptionHandler;
import com.learnova.prerequisite.dto.PrerequisiteEditorResponse;
import com.learnova.prerequisite.dto.PrerequisiteReplaceRequest;
import com.learnova.prerequisite.service.PrerequisiteService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.math.BigDecimal;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PrerequisiteControllerTest {

    private PrerequisiteService prerequisiteService;

    private MockMvc mockMvc;


    @BeforeEach
    void setUp() {

        prerequisiteService =
                mock(
                        PrerequisiteService.class
                );


        PrerequisiteController controller =
                new PrerequisiteController(
                        prerequisiteService
                );


        mockMvc =
                MockMvcBuilders
                        .standaloneSetup(
                                controller
                        )
                        .setControllerAdvice(
                                new GlobalExceptionHandler()
                        )
                        .build();
    }


    @Test
    void getEditorReturnsCanonicalResponse()
            throws Exception {

        when(
                prerequisiteService
                        .getEditor(
                                20L
                        )
        ).thenReturn(
                sampleResponse()
        );


        mockMvc.perform(
                        get(
                                "/api/v1/instructor/courses/20/prerequisites"
                        )
                )
                .andExpect(
                        status().isOk()
                )

                .andExpect(
                        jsonPath("$.success")
                                .value(true)
                )

                .andExpect(
                        jsonPath(
                                "$.data.targetCourseId"
                        )
                                .value(20)
                )

                .andExpect(
                        jsonPath(
                                "$.data.targetTitle"
                        )
                                .value(
                                        "Advanced Database Systems"
                                )
                )

                .andExpect(
                        jsonPath(
                                "$.data.editable"
                        )
                                .value(true)
                )

                .andExpect(
                        jsonPath(
                                "$.data.prerequisites[0].courseId"
                        )
                                .value(10)
                )

                .andExpect(
                        jsonPath(
                                "$.data.candidates[0].courseId"
                        )
                                .value(11)
                );
    }


    @Test
    void replacePrerequisitesReturnsFreshEditorState()
            throws Exception {

        when(
                prerequisiteService
                        .replacePrerequisites(
                                any(Long.class),
                                any(
                                        PrerequisiteReplaceRequest.class
                                )
                        )
        ).thenReturn(
                sampleResponse()
        );


        mockMvc.perform(
                        put(
                                "/api/v1/instructor/courses/20/prerequisites"
                        )

                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )

                                .content(
                                        """
                                        {
                                          "prerequisites": [
                                            {
                                              "prerequisiteCourseId": 10,
                                              "requiredMinScore": 60
                                            }
                                          ]
                                        }
                                        """
                                )
                )

                .andExpect(
                        status().isOk()
                )

                .andExpect(
                        jsonPath("$.success")
                                .value(true)
                )

                .andExpect(
                        jsonPath("$.message")
                                .value(
                                        "Prerequisites saved"
                                )
                )

                .andExpect(
                        jsonPath(
                                "$.data.prerequisites[0].requiredMinScore"
                        )
                                .value(60)
                );
    }


    @Test
    void invalidCourseIdReturnsBadRequest()
            throws Exception {

        when(
                prerequisiteService
                        .getEditor(
                                0L
                        )
        ).thenThrow(
                new IllegalArgumentException(
                        "A valid course id is required."
                )
        );


        mockMvc.perform(
                        get(
                                "/api/v1/instructor/courses/0/prerequisites"
                        )
                )
                .andExpect(
                        status().isBadRequest()
                )

                .andExpect(
                        jsonPath("$.success")
                                .value(false)
                )

                .andExpect(
                        jsonPath("$.message")
                                .value(
                                        "A valid course id is required."
                                )
                );
    }


    private PrerequisiteEditorResponse sampleResponse() {

        return new PrerequisiteEditorResponse(

                20L,

                "Advanced Database Systems",

                "advanced-database-systems",

                "draft",

                true,


                List.of(
                        new PrerequisiteEditorResponse.Prerequisite(

                                10L,

                                "Database Fundamentals",

                                "database-fundamentals",

                                "published",

                                new BigDecimal(
                                        "60.00"
                                )
                        )
                ),


                List.of(
                        new PrerequisiteEditorResponse.Candidate(

                                11L,

                                "SQL Fundamentals",

                                "sql-fundamentals",

                                "published"
                        )
                )
        );
    }
}
