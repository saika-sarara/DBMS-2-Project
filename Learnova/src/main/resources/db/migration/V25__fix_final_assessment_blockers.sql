-- V25: Fix critical course final-assessment blockers introduced in V23/V24.
-- Keep final-assessment business rules authoritative in PostgreSQL.

-- =========================================================
-- 1. Schema repair for course-level FINAL assessments
-- =========================================================

-- V23 originally added quiz_type with a misspelled default ('LESSSON'),
-- so normalize any legacy rows before using the corrected value.
UPDATE public.quizzes
SET quiz_type = 'LESSON'
WHERE quiz_type = 'LESSSON';

-- Lesson quizzes require lesson_id, but course-level FINAL assessments do not.
-- The existing FK/UNIQUE constraints remain safe because PostgreSQL permits NULL
-- in the lesson_id FK and multiple NULL values in a UNIQUE constraint.
ALTER TABLE public.quizzes
    ALTER COLUMN lesson_id DROP NOT NULL;

-- =========================================================
-- 2. Fix instructor question creation
--    - do not reuse sequence_order = 0
--    - serialize additions per assessment to avoid duplicate sequence values
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_final_assessment_question_create(
    p_actor_user_id BIGINT,
    p_assessment_id BIGINT,
    p_question_text TEXT,
    p_options_jsonb JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_correct_count INTEGER;
    v_options_count INTEGER;
    v_qid BIGINT;
    v_idx INTEGER;
    v_opt JSONB;
    v_label TEXT;
    v_sequence_order INTEGER;
BEGIN
    IF p_question_text IS NULL OR btrim(p_question_text) = '' THEN
        RAISE EXCEPTION 'LTQ20: Question text cannot be blank.'
            USING ERRCODE = 'LTQ20';
    END IF;

    IF p_options_jsonb IS NULL OR jsonb_typeof(p_options_jsonb) <> 'array' THEN
        RAISE EXCEPTION 'LTQ21: Options must be a JSON array with at least two options.'
            USING ERRCODE = 'LTQ21';
    END IF;

    -- Lock this assessment row so concurrent question creation cannot calculate
    -- the same next sequence_order.
    SELECT q.course_id
    INTO v_course_id
    FROM public.quizzes q
    WHERE q.id = p_assessment_id
      AND q.quiz_type = 'FINAL'
    FOR UPDATE;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Assessment % does not exist or is not FINAL.', p_assessment_id
            USING ERRCODE = 'LTQ03';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_user_id);

    v_options_count := jsonb_array_length(p_options_jsonb);
    IF v_options_count < 2 THEN
        RAISE EXCEPTION 'LTQ21: A question must have at least two options.'
            USING ERRCODE = 'LTQ21';
    END IF;

    SELECT COUNT(*)
    INTO v_correct_count
    FROM jsonb_array_elements(p_options_jsonb) AS opt
    WHERE COALESCE((opt->>'correct')::BOOLEAN, FALSE) IS TRUE;

    IF v_correct_count <> 1 THEN
        RAISE EXCEPTION 'LTQ22: Exactly one option must be marked correct.'
            USING ERRCODE = 'LTQ22';
    END IF;

    -- Use the next free sequence number instead of hard-coding 0.
    SELECT COALESCE(MAX(qq.sequence_order), -1) + 1
    INTO v_sequence_order
    FROM public.quiz_questions qq
    WHERE qq.quiz_id = p_assessment_id;

    INSERT INTO public.quiz_questions (quiz_id, question_text, sequence_order)
    VALUES (p_assessment_id, btrim(p_question_text), v_sequence_order)
    RETURNING id INTO v_qid;

    FOR v_idx IN 0..(v_options_count - 1) LOOP
        v_opt := p_options_jsonb->v_idx;

        IF v_opt->>'optionText' IS NULL OR btrim(v_opt->>'optionText') = '' THEN
            RAISE EXCEPTION 'LTQ23: Option text cannot be blank.'
                USING ERRCODE = 'LTQ23';
        END IF;

        v_label := chr(ascii('A') + v_idx);

        INSERT INTO public.quiz_options (
            question_id,
            option_label,
            option_text,
            is_correct
        )
        VALUES (
            v_qid,
            v_label,
            btrim(v_opt->>'optionText'),
            COALESCE((v_opt->>'correct')::BOOLEAN, FALSE)
        );
    END LOOP;

    RETURN v_qid;
END;
$$;

-- =========================================================
-- 3. Fix attempt creation and snapshotting
--    - enforce final-assessment content completion in PostgreSQL
--    - select only valid questions
--    - fix invalid alias / attempt_id self-comparison
--    - persist randomized question and option order
-- =========================================================

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
    v_attempt_id BIGINT;
    v_started_at TIMESTAMPTZ;
    v_attempt_no INTEGER;
    v_questions_per INTEGER;
    v_today_attempts INTEGER;
    v_daily_attempt_limit INTEGER;
    v_enrollment_status VARCHAR(20);
    v_enrollment_course_id BIGINT;
    v_enrollment_progress NUMERIC(5,2);
    v_enrollment_user_id BIGINT;
    v_quiz_type VARCHAR(20);
    v_quiz_course_id BIGINT;
    v_quiz_active BOOLEAN;
    v_valid_questions INTEGER;
BEGIN
    SELECT
        e.status,
        e.course_id,
        e.progress_pct,
        e.user_id
    INTO
        v_enrollment_status,
        v_enrollment_course_id,
        v_enrollment_progress,
        v_enrollment_user_id
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

    SELECT
        q.questions_per_attempt,
        q.daily_attempt_limit,
        q.quiz_type,
        q.course_id,
        q.is_active
    INTO
        v_questions_per,
        v_daily_attempt_limit,
        v_quiz_type,
        v_quiz_course_id,
        v_quiz_active
    FROM public.quizzes q
    WHERE q.id = p_quiz_id;

    IF v_questions_per IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Quiz % does not exist.', p_quiz_id
            USING ERRCODE = 'LTQ03';
    END IF;

    -- FINAL assessment rules must be enforced here, not in Java.
    IF v_quiz_type = 'FINAL' THEN
        IF v_quiz_active IS NOT TRUE THEN
            RAISE EXCEPTION 'LTQ25: Final assessment % is not active.', p_quiz_id
                USING ERRCODE = 'LTQ25';
        END IF;

        IF v_quiz_course_id IS NULL OR v_enrollment_course_id <> v_quiz_course_id THEN
            RAISE EXCEPTION 'LTQ26: Enrollment % does not belong to the final assessment course.', p_enrollment_id
                USING ERRCODE = 'LTQ26';
        END IF;

        IF COALESCE(v_enrollment_progress, 0) < 100.00 THEN
            RAISE EXCEPTION 'LTQ27: Complete 100%% of the course content before starting the final assessment.'
                USING ERRCODE = 'LTQ27';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM public.quiz_submissions qs
            WHERE qs.user_id = v_enrollment_user_id
              AND qs.quiz_id = p_quiz_id
              AND qs.passed = TRUE
        ) THEN
            RAISE EXCEPTION 'LTQ28: Final assessment has already been passed.'
                USING ERRCODE = 'LTQ28';
        END IF;
    END IF;

    -- Count only questions that are actually usable in an attempt.
    SELECT COUNT(*)
    INTO v_valid_questions
    FROM public.quiz_questions qq
    WHERE qq.quiz_id = p_quiz_id
      AND (
          SELECT COUNT(*)
          FROM public.quiz_options qo
          WHERE qo.question_id = qq.id
      ) >= 2
      AND (
          SELECT COUNT(*) FILTER (WHERE qo2.is_correct)
          FROM public.quiz_options qo2
          WHERE qo2.question_id = qq.id
      ) = 1;

    IF v_valid_questions < v_questions_per THEN
        RAISE EXCEPTION 'LTQ08: Not enough valid questions available for quiz %.', p_quiz_id
            USING ERRCODE = 'LTQ08';
    END IF;

    SELECT COUNT(*)
    INTO v_today_attempts
    FROM public.quiz_attempts qa
    WHERE qa.enrollment_id = p_enrollment_id
      AND qa.quiz_id = p_quiz_id
      AND qa.attempt_date = CURRENT_DATE;

    IF v_today_attempts >= v_daily_attempt_limit THEN
        RAISE EXCEPTION 'LTQ04: Daily attempt limit for this quiz was reached.'
            USING ERRCODE = 'LTQ04';
    END IF;

    SELECT COALESCE(MAX(qa.attempt_no), 0) + 1
    INTO v_attempt_no
    FROM public.quiz_attempts qa
    WHERE qa.enrollment_id = p_enrollment_id
      AND qa.quiz_id = p_quiz_id
      AND qa.attempt_date = CURRENT_DATE;

    INSERT INTO public.quiz_attempts (
        enrollment_id,
        quiz_id,
        attempt_date,
        attempt_no
    )
    VALUES (
        p_enrollment_id,
        p_quiz_id,
        CURRENT_DATE,
        v_attempt_no
    )
    RETURNING id, public.quiz_attempts.started_at
    INTO v_attempt_id, v_started_at;

    -- Pick only valid questions, randomly, and persist their display order.
    WITH valid_questions AS (
        SELECT qq.id AS question_id
        FROM public.quiz_questions qq
        WHERE qq.quiz_id = p_quiz_id
          AND (
              SELECT COUNT(*)
              FROM public.quiz_options qo
              WHERE qo.question_id = qq.id
          ) >= 2
          AND (
              SELECT COUNT(*) FILTER (WHERE qo2.is_correct)
              FROM public.quiz_options qo2
              WHERE qo2.question_id = qq.id
          ) = 1
    ),
    picked AS (
        SELECT vq.question_id
        FROM valid_questions vq
        ORDER BY RANDOM()
        LIMIT v_questions_per
    ),
    ordered AS (
        SELECT
            p.question_id,
            (ROW_NUMBER() OVER (ORDER BY RANDOM()))::INTEGER AS display_order
        FROM picked p
    )
    INSERT INTO public.quiz_attempt_questions (
        attempt_id,
        question_id,
        display_order
    )
    SELECT
        v_attempt_id,
        o.question_id,
        o.display_order
    FROM ordered o;

    -- Snapshot a fresh randomized option order for each selected question.
    INSERT INTO public.quiz_attempt_option_order (
        attempt_id,
        question_id,
        option_id,
        display_order
    )
    SELECT
        v_attempt_id,
        qaq.question_id,
        qo.id,
        (ROW_NUMBER() OVER (
            PARTITION BY qaq.question_id
            ORDER BY RANDOM()
        ))::INTEGER
    FROM public.quiz_attempt_questions qaq
    JOIN public.quiz_options qo
      ON qo.question_id = qaq.question_id
    WHERE qaq.attempt_id = v_attempt_id;

    attempt_id := v_attempt_id;
    quiz_id := p_quiz_id;
    enrollment_id := p_enrollment_id;
    attempt_no := v_attempt_no;
    started_at := v_started_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN (
            'LTQ01', 'LTQ02', 'LTQ03', 'LTQ04', 'LTQ08',
            'LTQ25', 'LTQ26', 'LTQ27', 'LTQ28'
        ) THEN
            RAISE;
        END IF;

        RAISE LOG 'sp_start_quiz_attempt unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while starting the quiz: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

-- =========================================================
-- 4. Fix final-assessment status
--    - a failed numeric score is NOT the same as a pass
--    - eligibility uses valid-question count, not raw-question count
-- =========================================================

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
    v_total_qcount INTEGER := 0;
    v_valid_qcount INTEGER := 0;
    v_qper INTEGER := 0;
    v_pass NUMERIC(5,2) := 60.00;
    v_attempts_today INTEGER := 0;
    v_daily_limit INTEGER := 0;
BEGIN
    enrolled := FALSE;
    content_complete := FALSE;
    eligible := FALSE;
    already_passed := FALSE;
    assessment_id := NULL;
    question_count := 0;
    questions_per_attempt := 0;
    passing_score := 60.00;
    attempts_today := 0;
    remaining_attempts := 0;

    SELECT e.id, e.progress_pct, e.status
    INTO v_enrollment_id, v_progress, v_status
    FROM public.enrollments e
    WHERE e.user_id = p_student_user_id
      AND e.course_id = p_course_id
    LIMIT 1;

    IF v_enrollment_id IS NULL THEN
        RETURN NEXT;
        RETURN;
    END IF;

    enrolled := TRUE;
    content_complete := COALESCE(v_progress, 0) >= 100.00;

    SELECT
        q.id,
        q.questions_per_attempt,
        q.passing_score,
        q.daily_attempt_limit
    INTO
        v_quiz_id,
        v_qper,
        v_pass,
        v_daily_limit
    FROM public.quizzes q
    WHERE q.course_id = p_course_id
      AND q.quiz_type = 'FINAL'
      AND q.is_active = TRUE
    LIMIT 1;

    IF v_quiz_id IS NULL THEN
        RETURN NEXT;
        RETURN;
    END IF;

    assessment_id := v_quiz_id;
    questions_per_attempt := COALESCE(v_qper, 0);
    passing_score := COALESCE(v_pass, 60.00);

    SELECT COUNT(*)
    INTO v_total_qcount
    FROM public.quiz_questions qq
    WHERE qq.quiz_id = v_quiz_id;

    SELECT COUNT(*)
    INTO v_valid_qcount
    FROM public.quiz_questions qq
    WHERE qq.quiz_id = v_quiz_id
      AND (
          SELECT COUNT(*)
          FROM public.quiz_options qo
          WHERE qo.question_id = qq.id
      ) >= 2
      AND (
          SELECT COUNT(*) FILTER (WHERE qo2.is_correct)
          FROM public.quiz_options qo2
          WHERE qo2.question_id = qq.id
      ) = 1;

    question_count := v_total_qcount;

    -- A pass means an actual passed submission (or an already-completed
    -- enrollment), not merely that final_score_pct has any numeric value.
    SELECT (
        v_status = 'completed'
        OR EXISTS (
            SELECT 1
            FROM public.quiz_submissions qs
            WHERE qs.user_id = p_student_user_id
              AND qs.quiz_id = v_quiz_id
              AND qs.passed = TRUE
        )
    )
    INTO already_passed;

    SELECT COUNT(*)
    INTO v_attempts_today
    FROM public.quiz_attempts qa
    WHERE qa.enrollment_id = v_enrollment_id
      AND qa.quiz_id = v_quiz_id
      AND qa.attempt_date = CURRENT_DATE;

    attempts_today := v_attempts_today;
    remaining_attempts := GREATEST(0, COALESCE(v_daily_limit, 0) - v_attempts_today);

    eligible :=
        content_complete
        AND NOT already_passed
        AND v_status = 'active'
        AND v_valid_qcount >= v_qper
        AND remaining_attempts > 0;

    RETURN NEXT;
    RETURN;
END;
$$;

-- =========================================================
-- 5. Rebuild student start snapshot with numeric question ordering
--    so display order 10 does not sort between 1 and 2.
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_final_assessment_start_attempt(
    p_student_user_id BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (attempt_id BIGINT, snapshot JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    v_enrollment_id BIGINT;
    v_quiz_id BIGINT;
    v_attempt_id BIGINT;
    v_row RECORD;
    v_snapshot JSONB;
BEGIN
    SELECT e.id
    INTO v_enrollment_id
    FROM public.enrollments e
    WHERE e.user_id = p_student_user_id
      AND e.course_id = p_course_id
    LIMIT 1;

    IF v_enrollment_id IS NULL THEN
        RAISE EXCEPTION 'LTQ01: Enrollment does not exist for student % and course %.',
            p_student_user_id, p_course_id
            USING ERRCODE = 'LTQ01';
    END IF;

    SELECT q.id
    INTO v_quiz_id
    FROM public.quizzes q
    WHERE q.course_id = p_course_id
      AND q.quiz_type = 'FINAL'
      AND q.is_active = TRUE
    LIMIT 1;

    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Final assessment not found for course %.', p_course_id
            USING ERRCODE = 'LTQ03';
    END IF;

    SELECT *
    INTO v_row
    FROM public.sp_start_quiz_attempt(v_enrollment_id, v_quiz_id);

    v_attempt_id := v_row.attempt_id;

    SELECT jsonb_build_object(
        'attemptId', v_attempt_id,
        'quizId', v_quiz_id,
        'enrollmentId', v_enrollment_id,
        'startedAt', (
            SELECT qa.started_at
            FROM public.quiz_attempts qa
            WHERE qa.id = v_attempt_id
        ),
        'questions', COALESCE(
            (
                SELECT jsonb_agg(question_json ORDER BY display_order)
                FROM (
                    SELECT
                        qaq.display_order,
                        jsonb_build_object(
                            'questionId', qaq.question_id,
                            'displayOrder', qaq.display_order,
                            'questionText', qq.question_text,
                            'options', COALESCE(
                                (
                                    SELECT jsonb_agg(
                                        jsonb_build_object(
                                            'optionId', qao.option_id,
                                            'displayLabel', chr(ascii('A') + qao.display_order - 1),
                                            'optionText', qo.option_text
                                        )
                                        ORDER BY qao.display_order
                                    )
                                    FROM public.quiz_attempt_option_order qao
                                    JOIN public.quiz_options qo
                                      ON qo.id = qao.option_id
                                    WHERE qao.attempt_id = v_attempt_id
                                      AND qao.question_id = qaq.question_id
                                ),
                                '[]'::jsonb
                            )
                        ) AS question_json
                    FROM public.quiz_attempt_questions qaq
                    JOIN public.quiz_questions qq
                      ON qq.id = qaq.question_id
                    WHERE qaq.attempt_id = v_attempt_id
                ) ordered_questions
            ),
            '[]'::jsonb
        )
    )
    INTO v_snapshot;

    attempt_id := v_attempt_id;
    snapshot := v_snapshot;

    RETURN NEXT;
    RETURN;
END;
$$;

-- End V25
