-- =========================================================
-- fn_quiz_pick_questions
--
-- FUNCTION for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Question sampling
-- Draws p_count random questions from a quiz's question bank.

CREATE OR REPLACE FUNCTION public.fn_quiz_pick_questions(
    p_quiz_id BIGINT,
    p_count   INTEGER
)
RETURNS TABLE (question_id BIGINT)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT q.id
    FROM public.quiz_questions q
    WHERE q.quiz_id = p_quiz_id
    ORDER BY RANDOM()
    LIMIT GREATEST(COALESCE(p_count, 1), 1);
END;
$$;
