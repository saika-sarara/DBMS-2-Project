package com.learnova.quiz.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.quiz.dto.FinalAssessmentUpsertRequest;
import com.learnova.quiz.dto.QuestionUpsertRequest;
import com.learnova.quiz.repository.OptionRepository;
import com.learnova.quiz.repository.QuestionRepository;
import com.learnova.quiz.repository.QuizRepository;
import org.springframework.stereotype.Service;

@Service
public class InstructorAssessmentService {

    private final QuizRepository quizRepository;
    private final QuestionRepository questionRepository;
    private final OptionRepository optionRepository;
    private final CurrentUserResolver currentUserResolver;

    public InstructorAssessmentService(
            QuizRepository quizRepository,
            QuestionRepository questionRepository,
            OptionRepository optionRepository,
            CurrentUserResolver currentUserResolver
    ) {
        this.quizRepository = quizRepository;
        this.questionRepository = questionRepository;
        this.optionRepository = optionRepository;
        this.currentUserResolver = currentUserResolver;
    }

    public Long upsertFinalAssessment(Long courseId, FinalAssessmentUpsertRequest req) {
        try {
            Long actor = currentUserResolver.getCurrentUserId();
            return quizRepository.upsertFinalAssessment(actor, courseId, req.getTitle(), req.getPassingScore(), req.getDailyAttemptLimit(), req.getIsActive());
        } catch (DatabaseException ex) {
            throw ex;
        }
    }

    public Long addQuestion(Long assessmentId, QuestionUpsertRequest req) {
        Long actor = currentUserResolver.getCurrentUserId();
        return questionRepository.addQuestion(actor, assessmentId, req.getQuestionText(), req.getOptions());
    }
}
