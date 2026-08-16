package com.learnova.quiz.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.quiz.dto.*;
import com.learnova.quiz.repository.LessonQuizRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class LessonQuizService {

    private final CurrentUserResolver currentUserResolver;
    private final LessonQuizRepository lessonQuizRepository;
    private final ObjectMapper objectMapper;

    public LessonQuizService(CurrentUserResolver currentUserResolver,
                             LessonQuizRepository lessonQuizRepository,
                             ObjectMapper objectMapper) {
        this.currentUserResolver = currentUserResolver;
        this.lessonQuizRepository = lessonQuizRepository;
        this.objectMapper = objectMapper;
    }

    public LessonQuizStatusResponse getStatus(String lesson, boolean bypass, String course) {
        Long userId = currentUserResolver.getCurrentUserId();
        Map<String, Object> row = lessonQuizRepository.status(userId, lesson, bypass, course);

        LessonQuizStatusResponse resp = new LessonQuizStatusResponse();
        resp.setPassed(Boolean.TRUE.equals(row.get("passed")));
        resp.setUsed(toInt(row.get("used")));
        resp.setAttemptsLeft(toInt(row.get("attempts_left")));
        resp.setLimit(toInt(row.get("limit")));
        resp.setExhausted(Boolean.TRUE.equals(row.get("exhausted")));
        return resp;
    }

    public List<LessonQuizQuestionDto> getQuestions(String lesson, boolean bypass, int count, String course) {
        Long userId = currentUserResolver.getCurrentUserId();
        int safeCount = Math.max(count, 1);
        List<Map<String, Object>> rows = lessonQuizRepository.questions(userId, lesson, bypass, safeCount, course);

        Map<Long, LessonQuizQuestionDto> byId = new LinkedHashMap<>();
        for (Map<String, Object> row : rows) {
            Long questionId = toLong(row.get("question_id"));
            if (questionId == null) continue;
            LessonQuizQuestionDto question = byId.computeIfAbsent(questionId, id -> {
                LessonQuizQuestionDto q = new LessonQuizQuestionDto();
                q.setId(id);
                q.setText(row.get("question_text") == null ? "" : String.valueOf(row.get("question_text")));
                q.setOptions(new ArrayList<>());
                return q;
            });
            if (row.get("option_text") != null) {
                question.getOptions().add(String.valueOf(row.get("option_text")));
            }
        }
        return new ArrayList<>(byId.values());
    }

    public LessonQuizSubmitResponse submit(String lesson, boolean bypass,
                                           List<LessonQuizAnswerDto> answers, String course) {
        Long userId = currentUserResolver.getCurrentUserId();
        String answersJson;
        try {
            answersJson = objectMapper.writeValueAsString(answers);
        } catch (Exception ex) {
            throw new DatabaseException("LT500", "Could not serialize answers: " + ex.getMessage());
        }

        Map<String, Object> row = lessonQuizRepository.submit(userId, lesson, bypass, answersJson, course);

        LessonQuizSubmitResponse resp = new LessonQuizSubmitResponse();
        resp.setScore(toDouble(row.get("score_pct")));
        resp.setPassed(Boolean.TRUE.equals(row.get("passed")));
        resp.setAlreadyPassed(Boolean.TRUE.equals(row.get("already_passed")));
        resp.setAttemptsLeft(toInt(row.get("attempts_left")));
        resp.setExhausted(Boolean.TRUE.equals(row.get("exhausted")));
        resp.setCorrectAnswers(parseCorrectAnswers(row.get("correct_answers")));
        return resp;
    }

    private List<LessonQuizCorrectAnswerDto> parseCorrectAnswers(Object value) {
        List<LessonQuizCorrectAnswerDto> result = new ArrayList<>();
        if (value == null) return result;
        try {
            JsonNode root = objectMapper.readTree(asJsonText(value));
            if (root.isArray()) {
                for (JsonNode node : root) {
                    LessonQuizCorrectAnswerDto dto = new LessonQuizCorrectAnswerDto();
                    dto.setId(node.path("id").asLong());
                    dto.setCorrect(node.path("correct").asText());
                    result.add(dto);
                }
            }
        } catch (Exception ex) {
            throw new DatabaseException("LT500", "Could not parse correct answers: " + ex.getMessage());
        }
        return result;
    }

    private String asJsonText(Object value) {
        if (value instanceof String) {
            return (String) value;
        }
        try {
            java.lang.reflect.Method m = value.getClass().getMethod("getValue");
            Object v = m.invoke(value);
            return v == null ? null : String.valueOf(v);
        } catch (Exception ex) {
            return String.valueOf(value);
        }
    }

    private int toInt(Object value) {
        return value instanceof Number ? ((Number) value).intValue() : 0;
    }

    private double toDouble(Object value) {
        return value instanceof Number ? ((Number) value).doubleValue() : 0.0;
    }

    private Long toLong(Object value) {
        return value instanceof Number ? ((Number) value).longValue() : null;
    }
}
