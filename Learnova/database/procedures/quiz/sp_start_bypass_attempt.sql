-- =========================================================
-- sp_start_bypass_attempt
--
-- PROCEDURE for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Starts a bypass attempt: passing the quiz of a prerequisite course
-- to unlock a target course without completing the prerequisite.

CREATE OR REPLACE FUNCTION public.sp_start_bypass_attempt(
    p_user_id                BIGINT,
    p_target_course_id       BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS TABLE (
    attempt_id             BIGINT,
    target_course_id       BIGINT,
    prerequisite_course_id BIGINT,
    attempt_no             INTEGER,
    started_at             TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_attempt_no     INTEGER;
    v_quiz_id        BIGINT;
    v_questions_per  INTEGER;
    v_is_prerequisite BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.course_prerequisites
        WHERE course_id = p_target_course_id
          AND prerequisite_course_id = p_prerequisite_course_id
    )
    INTO v_is_prerequisite;

    IF NOT v_is_prerequisite THEN
        RAISE EXCEPTION 'LTP01: Course % is not a prerequisite of course %.',
            p_prerequisite_course_id, p_target_course_id
            USING ERRCODE = 'LTP01';
    END IF;

    -- Bypass quizzes use a quiz from the prerequisite course.
    SELECT q.id, q.questions_per_attempt
    INTO v_quiz_id, v_questions_per
    FROM public.quizzes q
    JOIN public.lessons l ON l.id = q.lesson_id
    WHERE l.course_id = p_prerequisite_course_id
    ORDER BY l.sequence_order ASC, q.id ASC
    LIMIT 1;

    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Prerequisite course % has no quiz to bypass with.',
            p_prerequisite_course_id
            USING ERRCODE = 'LTQ03';
    END IF;

    SELECT COALESCE(MAX(attempt_no), 0) + 1
    INTO v_attempt_no
    FROM public.bypass_attempts
    WHERE user_id = p_user_id
      AND target_course_id = p_target_course_id
      AND prerequisite_course_id = p_prerequisite_course_id
      AND attempt_date = CURRENT_DATE;

    INSERT INTO public.bypass_attempts (
        user_id,
        target_course_id,
        prerequisite_course_id,
        attempt_date,
        attempt_no
    )
    VALUES (
        p_user_id,
        p_target_course_id,
        p_prerequisite_course_id,
        CURRENT_DATE,
        v_attempt_no
    )
    RETURNING
        public.bypass_attempts.id,
        public.bypass_attempts.target_course_id,
        public.bypass_attempts.prerequisite_course_id,
        public.bypass_attempts.attempt_no,
        public.bypass_attempts.started_at
    INTO attempt_id, target_course_id, prerequisite_course_id, attempt_no, started_at;

    INSERT INTO public.bypass_attempt_questions (attempt_id, source_question_id)
    SELECT attempt_id, qq.question_id
    FROM public.fn_quiz_pick_questions(v_quiz_id, v_questions_per) qq;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTP01', 'LTQ03') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_start_bypass_attempt unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while starting the bypass quiz: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
