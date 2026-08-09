package com.learnova.quiz.service;

import com.learnova.common.exception.DatabaseException;
import com.learnova.enrollment.repository.EnrollmentRepository;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.quiz.dto.*;
import com.learnova.quiz.repository.QuizRepository;
import com.learnova.quiz.repository.SubmissionRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class StudentAssessmentService {

    private final CurrentUserResolver currentUserResolver;
    private final QuizRepository quizRepository;
    private final SubmissionRepository submissionRepository;
    private final JdbcTemplate jdbcTemplate;

    public StudentAssessmentService(CurrentUserResolver currentUserResolver,
                                    QuizRepository quizRepository,
                                    SubmissionRepository submissionRepository,
                                    JdbcTemplate jdbcTemplate) {
        this.currentUserResolver = currentUserResolver;
        this.quizRepository = quizRepository;
        this.submissionRepository = submissionRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    public Map<String, Object> getStatusForCourse(Long courseId) {
        Long userId = currentUserResolver.getCurrentUserId();

        try {
            Map<String, Object> row = jdbcTemplate.queryForMap("SELECT * FROM public.fn_final_assessment_status(?, ?)", userId, courseId);
            if (row == null) {
                // not enrolled / no assessment
                return Map.of(
                        "enrolled", false,
                        "contentComplete", false,
                        "eligible", false,
                        "alreadyPassed", false,
                        "assessmentId", null,
                        "questionCount", 0,
                        "questionsPerAttempt", 0,
                        "passingScore", 0.0,
                        "attemptsToday", 0,
                        "remainingAttempts", 0
                );
            }
            // build a result map with safe defaults to avoid NullPointer in tests and callers
            java.util.Map<String, Object> result = new java.util.HashMap<>();
            result.put("enrolled", row.getOrDefault("enrolled", false));
            result.put("contentComplete", row.getOrDefault("content_complete", false));
            result.put("eligible", row.getOrDefault("eligible", false));
            result.put("alreadyPassed", row.getOrDefault("already_passed", false));
            result.put("assessmentId", row.get("assessment_id"));
            result.put("questionCount", row.getOrDefault("question_count", 0));
            result.put("questionsPerAttempt", row.getOrDefault("questions_per_attempt", 0));
            result.put("passingScore", row.getOrDefault("passing_score", 0.0));
            result.put("attemptsToday", row.getOrDefault("attempts_today", 0));
            result.put("remainingAttempts", row.getOrDefault("remaining_attempts", 0));
            return result;
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            return Map.of();
        }
    }

    public StudentAttemptResponse startAttempt(Long courseId) {
        Long userId = currentUserResolver.getCurrentUserId();

        List<Map<String, Object>> rows = jdbcTemplate.queryForList("SELECT * FROM public.sp_final_assessment_start_attempt(?, ?)", userId, courseId);
        if (rows.isEmpty()) throw new DatabaseException("LTQ01", "Could not start attempt");
        Map<String, Object> row = rows.get(0);
        Long attemptId = ((Number)row.get("attempt_id")).longValue();
        Object snapshotObj = row.get("snapshot");

        // snapshot is a JSONB column; map it into DTOs using simple parsing
        StudentAttemptResponse resp = new StudentAttemptResponse();
        resp.setAttemptId(attemptId);

        String snapshotJson = null;
        if (snapshotObj == null) {
            throw new DatabaseException("LT500", "Attempt snapshot missing");
        }
        if (snapshotObj instanceof String) {
            snapshotJson = (String) snapshotObj;
        } else {
            try {
                java.lang.reflect.Method m = snapshotObj.getClass().getMethod("getValue");
                Object v = m.invoke(snapshotObj);
                snapshotJson = v == null ? null : v.toString();
            } catch (Exception ex) {
                snapshotJson = snapshotObj.toString();
            }
        }

        try {
            com.fasterxml.jackson.databind.ObjectMapper om = new com.fasterxml.jackson.databind.ObjectMapper();
            com.fasterxml.jackson.databind.JsonNode root = om.readTree(snapshotJson);
            resp.setQuizId(root.path("quizId").asLong(0));
            resp.setEnrollmentId(root.path("enrollmentId").asLong(0));
            resp.setAttemptNo(0);
            if (root.has("startedAt") && !root.get("startedAt").isNull()) {
                resp.setStartedAt(OffsetDateTime.parse(root.get("startedAt").asText()));
            }
            List<StudentQuestionDto> questions = new ArrayList<>();
            com.fasterxml.jackson.databind.JsonNode qs = root.path("questions");
            if (qs.isArray()) {
                for (com.fasterxml.jackson.databind.JsonNode qn : qs) {
                    StudentQuestionDto q = new StudentQuestionDto();
                    q.setQuestionId(qn.path("questionId").asLong());
                    q.setDisplayOrder(qn.path("displayOrder").asInt());
                    q.setQuestionText(qn.path("questionText").asText());
                    List<StudentOptionDto> opts = new ArrayList<>();
                    com.fasterxml.jackson.databind.JsonNode os = qn.path("options");
                    if (os.isArray()) {
                        for (com.fasterxml.jackson.databind.JsonNode on : os) {
                            Long optionId = on.path("optionId").asLong();
                            String label = on.path("displayLabel").asText();
                            String text = on.path("optionText").asText();
                            opts.add(new StudentOptionDto(optionId, label, text));
                        }
                    }
                    q.setOptions(opts);
                    questions.add(q);
                }
            }
            resp.setQuestions(questions);
        } catch (Exception ex) {
            throw new DatabaseException("LT500", "Failed to parse attempt snapshot: " + ex.getMessage());
        }

        return resp;
    }

    public void saveAnswer(Long attemptId, Long questionId, Long selectedOptionId) {
        Long userId = currentUserResolver.getCurrentUserId();
        jdbcTemplate.update("SELECT public.sp_final_assessment_save_answer(?, ?, ?, ?)", userId, attemptId, questionId, selectedOptionId);
    }

    public SubmissionResponse submitAttempt(Long attemptId) {
        Long userId = currentUserResolver.getCurrentUserId();
        Map<String, Object> r;
        try {
            r = jdbcTemplate.queryForMap("SELECT * FROM public.sp_final_assessment_submit(?, ?)", userId, attemptId);
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            throw new DatabaseException("LTQ01", "Submit failed");
        }
        SubmissionResponse resp = new SubmissionResponse();
        resp.setAttemptId(((Number)r.get("attempt_id")).longValue());
        resp.setScorePct(((Number)r.get("score_pct")).doubleValue());
        resp.setPassed((Boolean)r.get("passed"));
        resp.setSubmittedAt((OffsetDateTime)r.get("submitted_at"));
        resp.setCourseCompleted((Boolean)r.get("course_completed"));
        resp.setPassingScore(((Number)r.get("passing_score")).doubleValue());
        resp.setMessage(resp.getPassed() ? "Passed" : "Failed");
        return resp;
    }

    public List<Map<String, Object>> historyForCourse(Long courseId) {
        Long userId = currentUserResolver.getCurrentUserId();
        return jdbcTemplate.queryForList("SELECT * FROM public.fn_final_assessment_history(?, ?)", userId, courseId);
    }
}
