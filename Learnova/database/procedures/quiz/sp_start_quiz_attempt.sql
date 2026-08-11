-- =========================================================
-- sp_start_quiz_attempt
--
-- PROCEDURE for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 5. Attempt lifecycle procedures
-- Starts a regular quiz attempt for an enrollment. Enforces the daily
-- attempt limit and snapshots the drawn questions.

CREATE OR REPLACE FUNCTION public.sp_start_quiz_attempt(
    p_enrollment_id BIGINT,
    p_quiz_id       BIGINT
)
RETURNS TABLE (
    attempt_id     BIGINT,
    quiz_id        BIGINT,
    enrollment_id  BIGINT,
    attempt_no     INTEGER,
    started_at     TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_attempt_no        INTEGER;
    v_questions_per     INTEGER;
    v_today_attempts    INTEGER;
    v_enrollment_status VARCHAR(20);
BEGIN
    SELECT e.status
    INTO v_enrollment_status
    FROM public.enrollments e
    WHERE e.id = p_enrollment_id;

    IF v_enrollment_status IS NULL THEN
        RAISE EXCEPTION 'LTQ01: Enrollment % does not exist.', p_enrollment_id
            USING ERRCODE = 'LTQ01';
    END IF;

    IF v_enrollment_status <> 'active' THEN
        RAISE EXCEPTION 'LTQ02: Only active enrollments can take quizzes.'
            USING ERRCODE = 'LTQ02';
    END IF;

    SELECT q.questions_per_attempt
    INTO v_questions_per
    FROM public.quizzes q
    WHERE q.id = p_quiz_id;

    IF v_questions_per IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Quiz % does not exist.', p_quiz_id
            USING ERRCODE = 'LTQ03';
    END IF;

    SELECT COUNT(*)
    INTO v_today_attempts
    FROM public.quiz_attempts
    WHERE enrollment_id = p_enrollment_id
      AND quiz_id = p_quiz_id
      AND attempt_date = CURRENT_DATE;

    SELECT COALESCE(MAX(attempt_no), 0) + 1
    INTO v_attempt_no
    FROM public.quiz_attempts
    WHERE enrollment_id = p_enrollment_id
      AND quiz_id = p_quiz_id
      AND attempt_date = CURRENT_DATE;

    IF v_today_attempts >= (
        SELECT daily_attempt_limit
        FROM public.quizzes
        WHERE id = p_quiz_id
    ) THEN
        RAISE EXCEPTION 'LTQ04: Daily attempt limit for this quiz was reached.'
            USING ERRCODE = 'LTQ04';
    END IF;

    INSERT INTO public.quiz_attempts (enrollment_id, quiz_id, attempt_date, attempt_no)
    VALUES (p_enrollment_id, p_quiz_id, CURRENT_DATE, v_attempt_no)
    RETURNING
        public.quiz_attempts.id,
        public.quiz_attempts.quiz_id,
        public.quiz_attempts.enrollment_id,
        public.quiz_attempts.attempt_no,
        public.quiz_attempts.started_at
    INTO attempt_id, quiz_id, enrollment_id, attempt_no, started_at;

    INSERT INTO public.quiz_attempt_questions (attempt_id, question_id)
    SELECT attempt_id, qq.question_id
    FROM public.fn_quiz_pick_questions(p_quiz_id, v_questions_per) qq;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTQ01', 'LTQ02', 'LTQ03', 'LTQ04') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_start_quiz_attempt unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while starting the quiz: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
