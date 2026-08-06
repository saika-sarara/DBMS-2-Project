-- =========================================================
-- sp_submit_quiz_attempt
--
-- PROCEDURE for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Grades a submitted attempt. Correct answers are recorded on the
-- attempt_answers / bypass_attempt_answers rows; the grade is the share
-- of correctly answered questions among the snapshot.
--   regular attempt (p_bypass_quiz = FALSE):
--     * writes quiz_submissions history
--     * keeps the best score on enrollments.final_score_pct
--   bypass attempt (p_bypass_quiz = TRUE):
--     * a passing score (>= 60%) inserts a course_bypasses row, which
--       satisfies the prerequisite (V9) and fires the V9 unlock trigger

CREATE OR REPLACE FUNCTION public.sp_submit_quiz_attempt(
    p_attempt_id  BIGINT,
    p_bypass_quiz BOOLEAN
)
RETURNS TABLE (
    attempt_id BIGINT,
    status     VARCHAR(20),
    score_pct  NUMERIC(5,2),
    passed     BOOLEAN,
    submitted_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total       INTEGER;
    v_correct     INTEGER;
    v_score       NUMERIC(5,2);
    v_passed      BOOLEAN;
    v_passing     NUMERIC(5,2) := 60.00;
    v_user_id     BIGINT;
    v_target      BIGINT;
    v_prereq      BIGINT;
    v_enrollment  BIGINT;
BEGIN
    IF p_bypass_quiz THEN
        SELECT ba.id, ba.user_id, ba.target_course_id, ba.prerequisite_course_id, ba.status
        INTO attempt_id, v_user_id, v_target, v_prereq, status
        FROM public.bypass_attempts ba
        WHERE ba.id = p_attempt_id;
    ELSE
        SELECT qa.id, qa.enrollment_id, qa.status
        INTO attempt_id, v_enrollment, status
        FROM public.quiz_attempts qa
        WHERE qa.id = p_attempt_id;
    END IF;

    IF attempt_id IS NULL THEN
        RAISE EXCEPTION 'LTQ01: Attempt % does not exist.', p_attempt_id
            USING ERRCODE = 'LTQ01';
    END IF;

    IF status = 'submitted' THEN
        RAISE EXCEPTION 'LTQ05: Attempt % was already submitted.', p_attempt_id
            USING ERRCODE = 'LTQ05';
    END IF;

    IF p_bypass_quiz THEN
        SELECT COUNT(*),
               COUNT(*) FILTER (WHERE aa.is_correct)
        INTO v_total, v_correct
        FROM public.bypass_attempt_questions baq
        LEFT JOIN public.bypass_attempt_answers aa
               ON aa.attempt_id = baq.attempt_id
              AND aa.source_question_id = baq.source_question_id
        WHERE baq.attempt_id = p_attempt_id;
    ELSE
        SELECT COUNT(*),
               COUNT(*) FILTER (WHERE aa.is_correct)
        INTO v_total, v_correct
        FROM public.quiz_attempt_questions qaq
        LEFT JOIN public.attempt_answers aa
               ON aa.attempt_id = qaq.attempt_id
              AND aa.question_id = qaq.question_id
        WHERE qaq.attempt_id = p_attempt_id;
    END IF;

    IF v_total IS NULL OR v_total = 0 THEN
        RAISE EXCEPTION 'LTQ06: Attempt % has no answered questions.', p_attempt_id
            USING ERRCODE = 'LTQ06';
    END IF;

    v_score := ROUND((v_correct::NUMERIC / v_total::NUMERIC) * 100, 2);

    IF p_bypass_quiz THEN
        -- Bypass quizzes always pass at the standard 60% threshold.
        v_passed := v_score >= v_passing;
    ELSE
        SELECT q.passing_score
        INTO v_passing
        FROM public.quizzes q
        JOIN public.quiz_attempts qa ON qa.quiz_id = q.id
        WHERE qa.id = p_attempt_id;

        v_passed := v_score >= COALESCE(v_passing, 60.00);
    END IF;

    IF p_bypass_quiz THEN
        UPDATE public.bypass_attempts
        SET status = 'submitted',
            submitted_at = CURRENT_TIMESTAMP,
            score_pct = v_score,
            passed = v_passed
        WHERE id = p_attempt_id;

        IF v_passed THEN
            INSERT INTO public.course_bypasses (user_id, target_course_id, prerequisite_course_id)
            VALUES (v_user_id, v_target, v_prereq)
            ON CONFLICT (user_id, target_course_id, prerequisite_course_id) DO NOTHING;
        END IF;
    ELSE
        UPDATE public.quiz_attempts
        SET status = 'submitted',
            submitted_at = CURRENT_TIMESTAMP,
            score_pct = v_score,
            passed = v_passed
        WHERE id = p_attempt_id;

        INSERT INTO public.quiz_submissions (user_id, quiz_id, score_pct, passed)
        SELECT e.user_id, qa.quiz_id, v_score, v_passed
        FROM public.quiz_attempts qa
        JOIN public.enrollments e ON e.id = qa.enrollment_id
        WHERE qa.id = p_attempt_id;

        -- Keep the best score as the enrollment's final score.
        UPDATE public.enrollments e
        SET final_score_pct = GREATEST(
                COALESCE(e.final_score_pct, v_score),
                v_score
            )
        FROM public.quiz_attempts qa
        WHERE qa.id = p_attempt_id
          AND e.id = qa.enrollment_id;
    END IF;

    score_pct := v_score;
    passed := v_passed;
    submitted_at := CURRENT_TIMESTAMP;
    status := 'submitted';
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTQ01', 'LTQ05', 'LTQ06') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_submit_quiz_attempt unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while submitting the quiz: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
