package com.learnova.quiz.repository;

import com.learnova.common.exception.DatabaseException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

@Repository
public class SubmissionRepository {

    private final JdbcTemplate jdbcTemplate;

    public SubmissionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Map<String, Object>> findSubmissionsByUserAndCourse(Long userId, Long courseId) {
        try {
            return jdbcTemplate.queryForList(
                    "SELECT qs.id, qs.quiz_id, qs.score_pct, qs.passed, qs.submitted_at FROM public.quiz_submissions qs JOIN public.quizzes q ON q.id = qs.quiz_id WHERE qs.user_id = ? AND q.course_id = ? ORDER BY qs.submitted_at DESC",
                    userId,
                    courseId
            );
        } catch (Exception ex) {
            throw DatabaseException.from(new org.springframework.dao.DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }
}
