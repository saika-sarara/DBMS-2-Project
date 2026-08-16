package com.learnova.prerequisite.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.learnova.common.exception.DatabaseException;
import com.learnova.common.exception.ResourceNotFoundException;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.prerequisite.dto.PrerequisiteEditorResponse;
import com.learnova.prerequisite.dto.PrerequisiteReplaceRequest;
import com.learnova.prerequisite.repository.PrerequisiteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.dao.DataAccessException;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PrerequisiteServiceTest {

    private CurrentUserResolver currentUserResolver;

    private PrerequisiteRepository prerequisiteRepository;

    private ObjectMapper objectMapper;

    private PrerequisiteService prerequisiteService;


    @BeforeEach
    void setUp() {

        currentUserResolver =
                mock(
                        CurrentUserResolver.class
                );


        prerequisiteRepository =
                mock(
                        PrerequisiteRepository.class
                );


        objectMapper =
                new ObjectMapper();


        prerequisiteService =
                new PrerequisiteService(
                        currentUserResolver,
                        prerequisiteRepository,
                        objectMapper
                );
    }


    @Test
    void getEditorMapsDatabaseJson() {

        when(
                currentUserResolver
                        .getCurrentUserId()
        ).thenReturn(
                9L
        );


        when(
                prerequisiteRepository
                        .findEditor(
                                9L,
                                20L
                        )
        ).thenReturn(
                new PrerequisiteRepository
                        .PrerequisiteEditorRow(

                        20L,

                        "Advanced Database Systems",

                        "advanced-database-systems",

                        "draft",

                        true,

                        """
                        [
                          {
                            "courseId": 10,
                            "title": "Database Fundamentals",
                            "slug": "database-fundamentals",
                            "status": "published",
                            "requiredMinScore": 60.00
                          }
                        ]
                        """,

                        """
                        [
                          {
                            "courseId": 11,
                            "title": "SQL Fundamentals",
                            "slug": "sql-fundamentals",
                            "status": "published"
                          }
                        ]
                        """
                )
        );


        PrerequisiteEditorResponse response =
                prerequisiteService
                        .getEditor(
                                20L
                        );


        assertEquals(
                20L,
                response.targetCourseId()
        );


        assertEquals(
                "Advanced Database Systems",
                response.targetTitle()
        );


        assertTrue(
                response.editable()
        );


        assertEquals(
                1,
                response.prerequisites().size()
        );


        assertEquals(
                10L,
                response
                        .prerequisites()
                        .get(0)
                        .courseId()
        );


        assertEquals(
                new BigDecimal("60.00"),
                response
                        .prerequisites()
                        .get(0)
                        .requiredMinScore()
        );


        assertEquals(
                1,
                response.candidates().size()
        );


        assertEquals(
                11L,
                response
                        .candidates()
                        .get(0)
                        .courseId()
        );
    }


    @Test
    void replacePrerequisitesUsesOneRepositoryCommand()
            throws Exception {

        when(
                currentUserResolver
                        .getCurrentUserId()
        ).thenReturn(
                9L
        );


        /*
         * Do not match JSON lexically.
         *
         * These are semantically equivalent:
         *
         *     70
         *     70.0
         *     70.00
         *
         * Jackson is free to choose a valid numeric representation.
         */
        when(
                prerequisiteRepository
                        .replacePrerequisites(
                                eq(9L),
                                eq(20L),
                                anyString()
                        )
        ).thenReturn(
                new PrerequisiteRepository
                        .PrerequisiteEditorRow(

                        20L,

                        "Advanced Database Systems",

                        "advanced-database-systems",

                        "draft",

                        true,

                        """
                        [
                          {
                            "courseId": 10,
                            "title": "Database Fundamentals",
                            "slug": "database-fundamentals",
                            "status": "published",
                            "requiredMinScore": 70
                          }
                        ]
                        """,

                        "[]"
                )
        );


        PrerequisiteReplaceRequest request =
                new PrerequisiteReplaceRequest(
                        List.of(
                                new PrerequisiteReplaceRequest.Item(
                                        10L,
                                        new BigDecimal("70")
                                )
                        )
                );


        PrerequisiteEditorResponse response =
                prerequisiteService
                        .replacePrerequisites(
                                20L,
                                request
                        );


        assertEquals(
                1,
                response.prerequisites().size()
        );


        assertEquals(
                0,
                response
                        .prerequisites()
                        .get(0)
                        .requiredMinScore()
                        .compareTo(
                                new BigDecimal("70")
                        )
        );


        /*
         * Capture the JSON actually passed to PostgreSQL and verify
         * its meaning instead of its whitespace/decimal formatting.
         */
        ArgumentCaptor<String> jsonCaptor =
                ArgumentCaptor.forClass(
                        String.class
                );


        verify(
                prerequisiteRepository
        ).replacePrerequisites(
                eq(9L),
                eq(20L),
                jsonCaptor.capture()
        );


        JsonNode payload =
                objectMapper.readTree(
                        jsonCaptor.getValue()
                );


        assertTrue(
                payload.isArray()
        );


        assertEquals(
                1,
                payload.size()
        );


        JsonNode first =
                payload.get(0);


        assertEquals(
                10L,
                first
                        .get(
                                "prerequisiteCourseId"
                        )
                        .asLong()
        );


        BigDecimal submittedScore =
                first
                        .get(
                                "requiredMinScore"
                        )
                        .decimalValue();


        assertEquals(
                0,
                submittedScore.compareTo(
                        new BigDecimal("70")
                )
        );
    }


    @Test
    void emptyPayloadCanClearAllPrerequisites() {

        when(
                currentUserResolver
                        .getCurrentUserId()
        ).thenReturn(
                9L
        );


        when(
                prerequisiteRepository
                        .replacePrerequisites(
                                9L,
                                20L,
                                "[]"
                        )
        ).thenReturn(
                new PrerequisiteRepository
                        .PrerequisiteEditorRow(

                        20L,

                        "Advanced Database Systems",

                        "advanced-database-systems",

                        "draft",

                        true,

                        "[]",

                        "[]"
                )
        );


        PrerequisiteEditorResponse response =
                prerequisiteService
                        .replacePrerequisites(

                                20L,

                                new PrerequisiteReplaceRequest(
                                        null
                                )
                        );


        assertTrue(
                response
                        .prerequisites()
                        .isEmpty()
        );


        verify(
                prerequisiteRepository
        ).replacePrerequisites(
                9L,
                20L,
                "[]"
        );
    }


    @Test
    void databaseBusinessRuleErrorIsPreserved() {

        when(
                currentUserResolver
                        .getCurrentUserId()
        ).thenReturn(
                9L
        );


        when(
                prerequisiteRepository
                        .replacePrerequisites(
                                9L,
                                20L,
                                "[]"
                        )
        ).thenThrow(
                new DataAccessException(
                        "cycle",
                        new SQLException(
                                "LTP02: Adding this prerequisite would create a circular dependency.",
                                "LTP02"
                        )
                ) {
                }
        );


        DatabaseException exception =
                assertThrows(
                        DatabaseException.class,
                        () ->
                                prerequisiteService
                                        .replacePrerequisites(

                                                20L,

                                                new PrerequisiteReplaceRequest(
                                                        List.of()
                                                )
                                        )
                );


        assertEquals(
                "LTP02",
                exception.getSqlState()
        );


        assertTrue(
                exception
                        .getMessage()
                        .contains(
                                "circular dependency"
                        )
        );
    }


    @Test
    void missingEditorRowBecomesNotFound() {

        when(
                currentUserResolver
                        .getCurrentUserId()
        ).thenReturn(
                9L
        );


        when(
                prerequisiteRepository
                        .findEditor(
                                9L,
                                999L
                        )
        ).thenReturn(
                null
        );


        assertThrows(
                ResourceNotFoundException.class,
                () ->
                        prerequisiteService
                                .getEditor(
                                        999L
                                )
        );
    }


    @Test
    void invalidCourseIdIsRejectedBeforeDatabaseCall() {

        assertThrows(
                IllegalArgumentException.class,
                () ->
                        prerequisiteService
                                .getEditor(
                                        0L
                                )
        );
    }


    @Test
    void editorCanBeReadOnly() {

        when(
                currentUserResolver
                        .getCurrentUserId()
        ).thenReturn(
                9L
        );


        when(
                prerequisiteRepository
                        .findEditor(
                                9L,
                                20L
                        )
        ).thenReturn(
                new PrerequisiteRepository
                        .PrerequisiteEditorRow(

                        20L,

                        "Published Course",

                        "published-course",

                        "published",

                        false,

                        "[]",

                        "[]"
                )
        );


        PrerequisiteEditorResponse response =
                prerequisiteService
                        .getEditor(
                                20L
                        );


        assertFalse(
                response.editable()
        );
    }
}