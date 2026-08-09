package com.learnova.quiz.service;

import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.quiz.dto.FinalAssessmentUpsertRequest;
import com.learnova.quiz.dto.OptionInput;
import com.learnova.quiz.dto.QuestionUpsertRequest;
import com.learnova.quiz.repository.OptionRepository;
import com.learnova.quiz.repository.QuestionRepository;
import com.learnova.quiz.repository.QuizRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class InstructorAssessmentServiceTest {

    private QuizRepository quizRepository;
    private QuestionRepository questionRepository;
    private OptionRepository optionRepository;
    private CurrentUserResolver currentUserResolver;
    private InstructorAssessmentService service;

    @BeforeEach
    void setUp() {
        quizRepository = mock(QuizRepository.class);
        questionRepository = mock(QuestionRepository.class);
        optionRepository = mock(OptionRepository.class);
        currentUserResolver = mock(CurrentUserResolver.class);
        service = new InstructorAssessmentService(quizRepository, questionRepository, optionRepository, currentUserResolver);
    }

    @Test
    void upsertFinalAssessment_createsOrUpdates() {
        FinalAssessmentUpsertRequest req = new FinalAssessmentUpsertRequest();
        req.setTitle("Final Test");
        req.setPassingScore(70.0);
        req.setDailyAttemptLimit(3);
        req.setIsActive(true);

        when(quizRepository.upsertFinalAssessment(1L, "Final Test", 70.0, 3, true)).thenReturn(123L);

        Long id = service.upsertFinalAssessment(1L, req);
        assertEquals(123L, id);
        verify(quizRepository, times(1)).upsertFinalAssessment(1L, "Final Test", 70.0, 3, true);
    }

    @Test
    void addQuestion_insertsOptionsAndQuestion() {
        QuestionUpsertRequest q = new QuestionUpsertRequest();
        q.setQuestionText("What is SQL?");
        OptionInput a = new OptionInput(); a.setOptionText("Structured Query Language"); a.setCorrect(true);
        OptionInput b = new OptionInput(); b.setOptionText("Something else"); b.setCorrect(false);
        q.setOptions(List.of(a,b));

        when(questionRepository.addQuestion(10L, "What is SQL?", q.getOptions())).thenReturn(999L);

        Long qid = service.addQuestion(10L, q);
        assertEquals(999L, qid);
        verify(questionRepository, times(1)).addQuestion(10L, "What is SQL?", q.getOptions());
    }
}
