package com.learnova.quiz.repository;

import com.learnova.common.exception.DatabaseException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

@Repository
public class LessonQuizRepository {

    private final JdbcTemplate jdbcTemplate;

    public LessonQuizRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Map<String, Object> status(Long actorUserId, String lesson, boolean bypass, String course) {
        try {
            return jdbcTemplate.queryForMap(
                    "SELECT * FROM public.fn_lesson_quiz_status(?, ?, ?, ?)",
                    actorUserId, lesson, bypass, course
            );
        } catch (Exception ex) {
            throw DatabaseException.from(new DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }

    public List<Map<String, Object>> questions(Long actorUserId, String lesson, boolean bypass, int count, String course) {
        try {
            return jdbcTemplate.queryForList(
                    "SELECT * FROM public.fn_lesson_quiz_questions(?, ?, ?, ?, ?)",
                    actorUserId, lesson, bypass, count, course
            );
        } catch (Exception ex) {
            throw DatabaseException.from(new DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }

    public Map<String, Object> submit(Long actorUserId, String lesson, boolean bypass, String answersJson, String course) {
        try {
            return jdbcTemplate.queryForMap(
                    "SELECT * FROM public.sp_submit_lesson_quiz(?, ?, ?, ?::jsonb, ?)",
                    actorUserId, lesson, bypass, answersJson, course
            );
        } catch (Exception ex) {
            throw DatabaseException.from(new DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }

    public List<Map<String, Object>> bank(Long actorUserId, String lesson, String course) {
        try {
            return jdbcTemplate.queryForList(
                    "SELECT * FROM public.fn_lesson_quiz_bank(?, ?, ?)",
                    actorUserId, lesson, course
            );
        } catch (Exception ex) {
            throw DatabaseException.from(new DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }

    public Long createQuestion(Long actorUserId, String lesson, String text, String optionsJson, String correct, String course) {
        try {
            return jdbcTemplate.queryForObject(
                    "SELECT * FROM public.sp_lesson_quiz_question_create(?, ?, ?, ?::jsonb, ?, ?)",
                    Long.class, actorUserId, lesson, text, optionsJson, correct, course
            );
        } catch (Exception ex) {
            throw DatabaseException.from(new DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }

    public Long updateQuestion(Long actorUserId, Long questionId, String text, String optionsJson, String correct) {
        try {
            return jdbcTemplate.queryForObject(
                    "SELECT * FROM public.sp_lesson_quiz_question_update(?, ?, ?, ?::jsonb, ?)",
                    Long.class, actorUserId, questionId, text, optionsJson, correct
            );
        } catch (Exception ex) {
            throw DatabaseException.from(new DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }

    public Long deleteQuestion(Long actorUserId, Long questionId) {
        try {
            return jdbcTemplate.queryForObject(
                    "SELECT * FROM public.sp_lesson_quiz_question_delete(?, ?)",
                    Long.class, actorUserId, questionId
            );
        } catch (Exception ex) {
            throw DatabaseException.from(new DataAccessResourceFailureException(ex.getMessage(), ex));
        }
    }
}
