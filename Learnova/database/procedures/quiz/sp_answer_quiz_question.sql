-- =========================================================
-- sp_answer_quiz_question
--
-- PROCEDURE for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Records the option a student picked for one question of an attempt.

CREATE OR REPLACE FUNCTION public.sp_answer_quiz_question(
    p_attempt_id         BIGINT,
    p_question_id        BIGINT,
    p_selected_option_id BIGINT,
    p_bypass_quiz        BOOLEAN
)
RETURNS TABLE (
    attempt_id  BIGINT,
    question_id BIGINT,
    is_correct  BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_correct BOOLEAN;
BEGIN
    SELECT qo.is_correct
    INTO v_correct
    FROM public.quiz_options qo
    WHERE qo.id = p_selected_option_id
      AND qo.question_id = p_question_id;

    IF v_correct IS NULL THEN
        RAISE EXCEPTION 'LTQ07: Option % does not belong to question %.',
            p_selected_option_id, p_question_id
            USING ERRCODE = 'LTQ07';
    END IF;

    IF p_bypass_quiz THEN
        INSERT INTO public.bypass_attempt_answers (
            attempt_id,
            source_question_id,
            selected_option_id,
            is_correct
        )
        VALUES (p_attempt_id, p_question_id, p_selected_option_id, v_correct)
        ON CONFLICT (attempt_id, source_question_id) DO UPDATE
            SET selected_option_id = EXCLUDED.selected_option_id,
                is_correct = EXCLUDED.is_correct,
                answered_at = CURRENT_TIMESTAMP;
    ELSE
        INSERT INTO public.attempt_answers (
            attempt_id,
            question_id,
            selected_option_id,
            is_correct
        )
        VALUES (p_attempt_id, p_question_id, p_selected_option_id, v_correct)
        ON CONFLICT (attempt_id, question_id) DO UPDATE
            SET selected_option_id = EXCLUDED.selected_option_id,
                is_correct = EXCLUDED.is_correct,
                answered_at = CURRENT_TIMESTAMP;
    END IF;

    attempt_id := p_attempt_id;
    question_id := p_question_id;
    is_correct := v_correct;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTQ07', 'LTQ01') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_answer_quiz_question unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while saving the answer: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
