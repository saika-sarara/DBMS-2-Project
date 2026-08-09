package com.learnova.quiz.repository;

import com.learnova.common.exception.DatabaseException;
import com.learnova.quiz.dto.OptionInput;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.List;

@Repository
public class QuestionRepository {

    private final JdbcTemplate jdbcTemplate;

    public QuestionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Long addQuestion(Long actorUserId, Long quizId, String questionText, List<OptionInput> options) {
        try {
            com.fasterxml.jackson.databind.ObjectMapper om = new com.fasterxml.jackson.databind.ObjectMapper();
            com.fasterxml.jackson.databind.node.ArrayNode arr = om.createArrayNode();
            for (OptionInput oi : options) {
                com.fasterxml.jackson.databind.node.ObjectNode on = om.createObjectNode();
                on.put("optionText", oi.getOptionText());
                on.put("correct", oi.getCorrect());
                arr.add(on);
            }
            String json = om.writeValueAsString(arr);
            Long qid = jdbcTemplate.queryForObject("SELECT public.sp_final_assessment_question_create(?, ?, ?, ?)::bigint", Long.class, actorUserId, quizId, questionText, json);
            return qid;
        } catch (Exception ex) {
            throw DatabaseException.from(new org.springframework.dao.DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }
}
