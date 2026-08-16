package com.learnova.quiz.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.quiz.dto.LessonQuizBankQuestionDto;
import com.learnova.quiz.dto.LessonQuizBankRequest;
import com.learnova.quiz.repository.LessonQuizRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class InstructorLessonQuizService {

    private final CurrentUserResolver currentUserResolver;
    private final LessonQuizRepository lessonQuizRepository;
    private final ObjectMapper objectMapper;

    public InstructorLessonQuizService(CurrentUserResolver currentUserResolver,
                                       LessonQuizRepository lessonQuizRepository,
                                       ObjectMapper objectMapper) {
        this.currentUserResolver = currentUserResolver;
        this.lessonQuizRepository = lessonQuizRepository;
        this.objectMapper = objectMapper;
    }

    public List<LessonQuizBankQuestionDto> getBank(String lesson, String course) {
        Long userId = currentUserResolver.getCurrentUserId();
        List<Map<String, Object>> rows = lessonQuizRepository.bank(userId, lesson, course);

        Map<Long, LessonQuizBankQuestionDto> byId = new LinkedHashMap<>();
        for (Map<String, Object> row : rows) {
            Long questionId = toLong(row.get("question_id"));
            if (questionId == null) continue;
            LessonQuizBankQuestionDto question = byId.computeIfAbsent(questionId, id -> {
                LessonQuizBankQuestionDto q = new LessonQuizBankQuestionDto();
                q.setId(id);
                q.setText(row.get("question_text") == null ? "" : String.valueOf(row.get("question_text")));
                q.setOptions(new ArrayList<>());
                q.setCorrect("");
                return q;
            });
            if (row.get("option_text") != null) {
                question.getOptions().add(String.valueOf(row.get("option_text")));
            }
            if (Boolean.TRUE.equals(row.get("is_correct")) && row.get("option_label") != null) {
                question.setCorrect(String.valueOf(row.get("option_label")));
            }
        }
        return new ArrayList<>(byId.values());
    }

    public Long createQuestion(String lesson, LessonQuizBankRequest request, String course) {
        Long userId = currentUserResolver.getCurrentUserId();
        return lessonQuizRepository.createQuestion(
                userId, lesson, request.getText(),
                toJsonArray(request.getOptions()),
                request.getCorrect(), course
        );
    }

    public Long updateQuestion(Long questionId, LessonQuizBankRequest request) {
        Long userId = currentUserResolver.getCurrentUserId();
        return lessonQuizRepository.updateQuestion(
                userId, questionId, request.getText(),
                toJsonArray(request.getOptions()),
                request.getCorrect()
        );
    }

    public Long deleteQuestion(Long questionId) {
        Long userId = currentUserResolver.getCurrentUserId();
        return lessonQuizRepository.deleteQuestion(userId, questionId);
    }

    private String toJsonArray(List<String> options) {
        try {
            return objectMapper.writeValueAsString(options);
        } catch (Exception ex) {
            throw new DatabaseException("LT500", "Could not serialize options: " + ex.getMessage());
        }
    }

    private Long toLong(Object value) {
        return value instanceof Number ? ((Number) value).longValue() : null;
    }
}
