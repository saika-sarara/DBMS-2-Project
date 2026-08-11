package com.learnova.quiz.repository;

import com.learnova.common.exception.DatabaseException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class OptionRepository {

    private final JdbcTemplate jdbcTemplate;

    public OptionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void deleteOptionsForQuestion(Long questionId) {
        try {
            jdbcTemplate.update("DELETE FROM public.quiz_options WHERE question_id = ?", questionId);
        } catch (Exception ex) {
            throw DatabaseException.from(new org.springframework.dao.DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }
}
