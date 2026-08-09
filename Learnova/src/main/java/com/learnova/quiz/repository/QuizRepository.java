package com.learnova.quiz.repository;

import com.learnova.common.exception.DatabaseException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.Map;

@Repository
public class QuizRepository {

    private final JdbcTemplate jdbcTemplate;

    public QuizRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Long upsertFinalAssessment(Long actorUserId, Long courseId, String title, Double passingScore, Integer dailyAttemptLimit, Boolean isActive) {
        try {
            Long id = jdbcTemplate.queryForObject(
                    "SELECT public.sp_final_assessment_upsert(?, ?, ?, ?, ?, ?)::bigint",
                    Long.class, actorUserId, courseId, title, passingScore, dailyAttemptLimit, isActive);
            return id;
        } catch (Exception ex) {
            throw DatabaseException.from(new org.springframework.dao.DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }

    public Map<String, Object> findFinalQuizByCourse(Long courseId) {
        try {
            return jdbcTemplate.queryForMap(
                    "SELECT id AS quiz_id, passing_score, questions_per_attempt, daily_attempt_limit, is_active FROM public.quizzes WHERE course_id = ? AND quiz_type = 'FINAL'",
                    courseId
            );
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            return null;
        } catch (Exception ex) {
            throw DatabaseException.from(new org.springframework.dao.DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }
}
