package com.learnova.quiz.service;

import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.quiz.repository.QuizRepository;
import com.learnova.quiz.repository.SubmissionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class StudentAssessmentServiceTest {

    private CurrentUserResolver currentUserResolver;
    private QuizRepository quizRepository;
    private SubmissionRepository submissionRepository;
    private JdbcTemplate jdbcTemplate;
    private StudentAssessmentService service;

    @BeforeEach
    void setUp() {
        currentUserResolver = mock(CurrentUserResolver.class);
        quizRepository = mock(QuizRepository.class);
        submissionRepository = mock(SubmissionRepository.class);
        jdbcTemplate = mock(JdbcTemplate.class);
        service = new StudentAssessmentService(currentUserResolver, quizRepository, submissionRepository, jdbcTemplate);
    }

    @Test
    void getStatusWhenNotEnrolled() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(42L);
        when(quizRepository.findFinalQuizByCourse(5L)).thenReturn(null);
        when(jdbcTemplate.queryForObject(anyString(), eq(Integer.class), any())).thenReturn(0);

        Map<String, Object> status = service.getStatusForCourse(5L);
        assertFalse((Boolean)status.get("contentComplete"));
        assertFalse((Boolean)status.get("eligible"));
    }

    @Test
    void getAttemptParsesSnapshotFromDatabase() {
        when(currentUserResolver.getCurrentUserId()).thenReturn(42L);
        when(jdbcTemplate.queryForObject(
                eq("SELECT public.fn_final_assessment_attempt_get(?, ?)"),
                eq(Object.class),
                eq(42L),
                eq(99L)
        )).thenReturn("{\"attemptId\":99,\"quizId\":7,\"enrollmentId\":5,\"startedAt\":\"2024-01-01T10:00:00Z\",\"questions\":[{\"questionId\":1,\"displayOrder\":1,\"questionText\":\"Q1?\",\"options\":[{\"optionId\":10,\"displayLabel\":\"A\",\"optionText\":\"Alpha\"},{\"optionId\":11,\"displayLabel\":\"B\",\"optionText\":\"Beta\"}]}]}");

        var attempt = service.getAttempt(99L);

        assertEquals(99L, attempt.getAttemptId());
        assertEquals(7L, attempt.getQuizId());
        assertEquals(5L, attempt.getEnrollmentId());
        assertEquals(1, attempt.getQuestions().size());
        assertEquals(1L, attempt.getQuestions().get(0).getQuestionId());
        assertEquals(2, attempt.getQuestions().get(0).getOptions().size());
    }
}
