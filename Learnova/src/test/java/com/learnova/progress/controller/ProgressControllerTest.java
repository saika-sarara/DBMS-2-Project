package com.learnova.progress.controller;

import com.learnova.common.exception.DatabaseException;
import com.learnova.common.exception.GlobalExceptionHandler;
import com.learnova.quiz.dto.LessonQuizCorrectAnswerDto;
import com.learnova.quiz.dto.LessonQuizSubmitRequest;
import com.learnova.quiz.dto.LessonQuizSubmitResponse;
import com.learnova.quiz.service.LessonQuizService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ProgressControllerTest {

    private LessonQuizService lessonQuizService;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        lessonQuizService = mock(LessonQuizService.class);
        ProgressController controller = new ProgressController(lessonQuizService);
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void submitsLessonQuizAndReturnsGradingResult() throws Exception {
        LessonQuizSubmitResponse response = new LessonQuizSubmitResponse(
                100.0,
                true,
                false,
                2,
                false,
                List.of(new LessonQuizCorrectAnswerDto(1L, "A"))
        );
        when(lessonQuizService.submit(
                eq("lesson-one"),
                eq(false),
                any(),
                eq("course-one")
        )).thenReturn(response);

        mockMvc.perform(post("/api/v1/progress/course-one/lessons/lesson-one/quiz")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "answers": [{"id": 1, "selected": "a"}],
                                  "bypass": false
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.score").value(100.0))
                .andExpect(jsonPath("$.data.passed").value(true))
                .andExpect(jsonPath("$.data.attemptsLeft").value(2))
                .andExpect(jsonPath("$.data.correctAnswers[0].id").value(1))
                .andExpect(jsonPath("$.data.correctAnswers[0].correct").value("A"));

        verify(lessonQuizService).submit(
                eq("lesson-one"),
                eq(false),
                any(),
                eq("course-one")
        );
    }

    @Test
    void forwardsBypassFlagToLessonQuizService() throws Exception {
        when(lessonQuizService.submit(eq("lesson"), eq(true), any(), eq("course")))
                .thenReturn(new LessonQuizSubmitResponse(60.0, true, false, 0, false, List.of()));

        mockMvc.perform(post("/api/v1/progress/course/lessons/lesson/quiz")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"answers": [{"id": 7, "selected": "D"}], "bypass": true}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.passed").value(true));

        verify(lessonQuizService).submit(eq("lesson"), eq(true), any(), eq("course"));
    }

    @Test
    void rejectsInvalidAnswerDataBeforeCallingService() throws Exception {
        mockMvc.perform(post("/api/v1/progress/course/lessons/lesson/quiz")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"answers": [{"id": 0, "selected": "Z"}]}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void returnsBadRequestWhenDatabaseRejectsLessonOrQuiz() throws Exception {
        when(lessonQuizService.submit(eq("missing-lesson"), eq(false), any(), eq("course")))
                .thenThrow(new DatabaseException("LTQ01", "Lesson quiz was not found."));

        mockMvc.perform(post("/api/v1/progress/course/lessons/missing-lesson/quiz")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{" +
                                "\"answers\":[{\"id\":1,\"selected\":\"A\"}]" +
                                "}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Lesson quiz was not found."));
    }

    @Test
    void requiresStudentRoleOnSubmissionEndpoint() throws Exception {
        PreAuthorize preAuthorize = ProgressController.class
                .getDeclaredMethod(
                        "submitLessonQuiz",
                        String.class,
                        String.class,
                        LessonQuizSubmitRequest.class
                )
                .getAnnotation(PreAuthorize.class);

        assertTrue(preAuthorize != null);
        assertEquals("hasRole('STUDENT')", preAuthorize.value());
    }
}