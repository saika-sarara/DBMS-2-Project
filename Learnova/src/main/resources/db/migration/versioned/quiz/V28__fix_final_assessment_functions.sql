-- =====================================================================
-- V28 - Fix broken final-assessment attempt plumbing (P0)
--
-- Current-state audit findings this migration repairs:
--   * V23 sp_start_quiz_attempt snapshot step referenced a non-existent
--     alias "a" (SQLSTATE 42P01) AND used an always-true WHERE clause
--     (attempt_id = attempt_id), so starting a final assessment always
--     fell into the LT500 fallback.
--   * V24 fn_final_assessment_status read enrollments.final_score_pct
--     (also written by lesson quizzes) straight into a BOOLEAN variable
--     (invalid cast, SQLSTATE 42804) as "already passed the final", and
--     required status='active' even though progress triggers set
--     status='completed' at 100% -- making the final assessment never
--     eligible.
--
-- Applied versioned migrations are never edited; corrections are shipped
-- as new overrides. Signatures are unchanged (CREATE OR REPLACE).
-- =====================================================================

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
    v_valid_questions   INTEGER;
    v_this_attempt      BIGINT;
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

    -- Count valid questions (>=2 options and exactly one correct)
    SELECT COUNT(*)
    INTO v_valid_questions
    FROM public.quiz_questions qq
    WHERE qq.quiz_id = p_quiz_id
      AND (
          SELECT COUNT(*) FROM public.quiz_options qo WHERE qo.question_id = qq.id
      ) >= 2
      AND (
          SELECT COUNT(*) FILTER (WHERE qo2.is_correct) FROM public.quiz_options qo2 WHERE qo2.question_id = qq.id
      ) = 1;

    IF v_valid_questions < v_questions_per THEN
        RAISE EXCEPTION 'LTQ08: Not enough valid questions available for quiz %.', p_quiz_id
            USING ERRCODE = 'LTQ08';
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

    v_this_attempt := attempt_id;

    -- Snapshot question IDs and assign a randomized display_order 1..n
    WITH picked AS (
        SELECT question_id FROM public.fn_quiz_pick_questions(p_quiz_id, v_questions_per)
    ), ordered AS (
        SELECT question_id, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS dorder
        FROM picked
    )
    INSERT INTO public.quiz_attempt_questions (attempt_id, question_id, display_order)
    SELECT attempt_id, question_id, dorder FROM ordered;

    -- For each question of THIS attempt only, snapshot randomized option
    -- order (fixes the always-true predicate / missing alias from V23).
    INSERT INTO public.quiz_attempt_option_order (attempt_id, question_id, option_id, display_order)
    SELECT
        aq.attempt_id,
        aq.question_id,
        o.id AS option_id,
        ROW_NUMBER() OVER (PARTITION BY aq.question_id ORDER BY RANDOM()) AS option_order
    FROM public.quiz_attempt_questions aq
    JOIN public.quiz_options o ON o.question_id = aq.question_id
    WHERE aq.attempt_id = v_this_attempt;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTQ01', 'LTQ02', 'LTQ03', 'LTQ04', 'LTQ08') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_start_quiz_attempt unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while starting the quiz: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_final_assessment_status(
    p_student_user_id BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    enrolled BOOLEAN,
    content_complete BOOLEAN,
    eligible BOOLEAN,
    already_passed BOOLEAN,
    assessment_id BIGINT,
    question_count INTEGER,
    questions_per_attempt INTEGER,
    passing_score NUMERIC(5,2),
    attempts_today INTEGER,
    remaining_attempts INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_enrollment_id BIGINT;
    v_progress NUMERIC(5,2);
    v_status VARCHAR(20);
    v_quiz_id BIGINT;
    v_qcount INTEGER;
    v_qper INTEGER;
    v_pass NUMERIC(5,2);
    v_attempts_today INTEGER;
    v_daily_limit INTEGER;
    v_already_passed BOOLEAN;
BEGIN
    enrolled := FALSE; content_complete := FALSE; eligible := FALSE; already_passed := FALSE;
    assessment_id := NULL; question_count := 0; questions_per_attempt := 0; passing_score := 60.00; attempts_today := 0; remaining_attempts := 0;

    SELECT id, progress_pct, status
    INTO v_enrollment_id, v_progress, v_status
    FROM public.enrollments WHERE user_id = p_student_user_id AND course_id = p_course_id LIMIT 1;

    IF v_enrollment_id IS NULL THEN
        enrolled := FALSE;
        RETURN NEXT;
        RETURN;
    END IF;
    enrolled := TRUE;
    content_complete := COALESCE(v_progress, 0) >= 100.0;
    already_passed := FALSE;

    SELECT id, questions_per_attempt, passing_score, daily_attempt_limit INTO v_quiz_id, v_qper, v_pass, v_daily_limit
    FROM public.quizzes WHERE course_id = p_course_id AND quiz_type = 'FINAL' AND is_active = TRUE LIMIT 1;

    IF v_quiz_id IS NULL THEN
        assessment_id := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    assessment_id := v_quiz_id;
    questions_per_attempt := v_qper;
    passing_score := v_pass;

    -- "already passed" is scored only by the FINAL quiz's own submissions,
    -- never by lesson-quiz scores stored in enrollments.final_score_pct.
    SELECT EXISTS (
        SELECT 1 FROM public.quiz_submissions qs
        WHERE qs.user_id = p_student_user_id
          AND qs.quiz_id = v_quiz_id
          AND qs.passed
    ) INTO v_already_passed;
    already_passed := v_already_passed;

    SELECT COUNT(*) INTO v_qcount FROM public.quiz_questions qq WHERE qq.quiz_id = v_quiz_id;
    question_count := v_qcount;

    SELECT COUNT(*) INTO v_attempts_today
    FROM public.quiz_attempts
    WHERE enrollment_id = v_enrollment_id AND quiz_id = v_quiz_id AND attempt_date = CURRENT_DATE;
    attempts_today := v_attempts_today;
    remaining_attempts := GREATEST(0, COALESCE(v_daily_limit, 0) - v_attempts_today);

    -- Eligibility: content completed, not already passed, and an attempt
    -- left today. Enrollment may be 'active' or 'completed' (progress
    -- triggers flip status to 'completed' exactly at 100%).
    eligible := content_complete AND NOT already_passed AND v_qcount >= v_qper AND remaining_attempts > 0 AND v_status IN ('active', 'completed');

    RETURN NEXT;
    RETURN;
END;
$$;