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
}
