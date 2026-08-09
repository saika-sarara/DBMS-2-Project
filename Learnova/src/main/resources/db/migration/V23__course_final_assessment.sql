-- V15: Course Final Assessment
-- Add support for FINAL quizzes (course-level), persist attempt question and option ordering,
-- and adjust progress function to respect final assessments.

-- 1. Extend quizzes table: course_id, quiz_type, is_active, enforce questions_per_attempt=10 for FINAL
ALTER TABLE public.quizzes
ADD COLUMN IF NOT EXISTS course_id BIGINT;

ALTER TABLE public.quizzes
ADD COLUMN IF NOT EXISTS quiz_type VARCHAR(20) NOT NULL DEFAULT 'LESSSON';

ALTER TABLE public.quizzes
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- fix typo default if any previously created; set default properly
ALTER TABLE public.quizzes ALTER COLUMN quiz_type SET DEFAULT 'LESSON';

-- Add FK to courses for course-level quizzes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_schema = 'public'
          AND tc.table_name = 'quizzes'
          AND tc.constraint_type = 'FOREIGN KEY'
          AND kcu.column_name = 'course_id'
    ) THEN
        ALTER TABLE public.quizzes
        ADD CONSTRAINT fk_quizzes_course
            FOREIGN KEY (course_id)
            REFERENCES public.courses (id)
            ON DELETE CASCADE;
    END IF;
END
$$;

-- Ensure FINAL quizzes must have course_id and exactly 10 questions_per_attempt
ALTER TABLE public.quizzes
ADD CONSTRAINT chk_quizzes_final_questions_per_attempt
    CHECK (quiz_type <> 'FINAL' OR questions_per_attempt = 10);

ALTER TABLE public.quizzes
ADD CONSTRAINT chk_quizzes_final_course_not_null
    CHECK (quiz_type <> 'FINAL' OR course_id IS NOT NULL);

-- Unique final quiz per course
CREATE UNIQUE INDEX IF NOT EXISTS uq_quizzes_course_final
ON public.quizzes (course_id)
WHERE quiz_type = 'FINAL';

-- 2. Persist question display order: add display_order to quiz_attempt_questions
ALTER TABLE public.quiz_attempt_questions
ADD COLUMN IF NOT EXISTS display_order INTEGER;

-- Ensure within an attempt display_order is unique
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'quiz_attempt_questions'
          AND indexname = 'uq_quiz_attempt_questions_attempt_display_order'
    ) THEN
        CREATE UNIQUE INDEX uq_quiz_attempt_questions_attempt_display_order
        ON public.quiz_attempt_questions (attempt_id, display_order);
    END IF;
END
$$;

-- 3. Snapshot option order per attempt/question
CREATE TABLE IF NOT EXISTS public.quiz_attempt_option_order (
    attempt_id BIGINT NOT NULL,
    question_id BIGINT NOT NULL,
    option_id BIGINT NOT NULL,
    display_order INTEGER NOT NULL,

    CONSTRAINT pk_quiz_attempt_option_order PRIMARY KEY (attempt_id, question_id, option_id),

    CONSTRAINT fk_qaoo_attempt FOREIGN KEY (attempt_id)
        REFERENCES public.quiz_attempts (id) ON DELETE CASCADE,

    CONSTRAINT fk_qaoo_question FOREIGN KEY (question_id)
        REFERENCES public.quiz_questions (id) ON DELETE CASCADE,

    CONSTRAINT fk_qaoo_option FOREIGN KEY (option_id)
        REFERENCES public.quiz_options (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_qaoo_attempt_question_display
ON public.quiz_attempt_option_order (attempt_id, question_id, display_order);

-- 4. Ensure there are enough valid questions before starting final attempt
-- Extend fn_quiz_pick_questions not needed; replace sp_start_quiz_attempt to snapshot orders

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

    -- Snapshot question IDs and assign a randomized display_order 1..n
    WITH picked AS (
        SELECT question_id FROM public.fn_quiz_pick_questions(p_quiz_id, v_questions_per)
    ), ordered AS (
        SELECT question_id, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS dorder
        FROM picked
    )
    INSERT INTO public.quiz_attempt_questions (attempt_id, question_id, display_order)
    SELECT attempt_id, question_id, dorder FROM ordered;

    -- For each question, snapshot option order randomized
    INSERT INTO public.quiz_attempt_option_order (attempt_id, question_id, option_id, display_order)
    SELECT
        a.attempt_id,
        q.question_id,
        o.id AS option_id,
        ROW_NUMBER() OVER (PARTITION BY q.question_id ORDER BY RANDOM()) AS option_order
    FROM (
        SELECT attempt_id, question_id FROM public.quiz_attempt_questions WHERE attempt_id = attempt_id
    ) q
    JOIN public.quiz_options o ON o.question_id = q.question_id;

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

-- 5. Replace sp_answer_quiz_question to verify attempt ownership and that the question belongs to the attempt
CREATE OR REPLACE FUNCTION public.sp_answer_quiz_question(
    p_attempt_id         BIGINT,
    p_question_id        BIGINT,
    p_selected_option_id BIGINT,
    p_bypass_quiz        BOOLEAN,
    p_user_id            BIGINT
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
    v_belongs BOOLEAN;
    v_owner BIGINT;
BEGIN
    -- Verify the option belongs to the question
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
        -- Verify attempt belongs to user
        SELECT ba.user_id
        INTO v_owner
        FROM public.bypass_attempts ba
        WHERE ba.id = p_attempt_id;

        IF v_owner IS NULL OR v_owner <> p_user_id THEN
            RAISE EXCEPTION 'LTQ09: Attempt % does not belong to user %.', p_attempt_id, p_user_id
                USING ERRCODE = 'LTQ09';
        END IF;

        -- Verify question is part of attempt
        SELECT EXISTS (
            SELECT 1 FROM public.bypass_attempt_questions baq
            WHERE baq.attempt_id = p_attempt_id
              AND baq.source_question_id = p_question_id
        ) INTO v_belongs;

        IF NOT v_belongs THEN
            RAISE EXCEPTION 'LTQ11: Question % is not part of attempt %.', p_question_id, p_attempt_id
                USING ERRCODE = 'LTQ11';
        END IF;

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
        -- Regular attempt: verify ownership via enrollment -> user
        SELECT e.user_id
        INTO v_owner
        FROM public.quiz_attempts qa
        JOIN public.enrollments e ON e.id = qa.enrollment_id
        WHERE qa.id = p_attempt_id;

        IF v_owner IS NULL OR v_owner <> p_user_id THEN
            RAISE EXCEPTION 'LTQ09: Attempt % does not belong to user %.', p_attempt_id, p_user_id
                USING ERRCODE = 'LTQ09';
        END IF;

        -- Verify question is part of this attempt
        SELECT EXISTS (
            SELECT 1 FROM public.quiz_attempt_questions qaq
            WHERE qaq.attempt_id = p_attempt_id
              AND qaq.question_id = p_question_id
        ) INTO v_belongs;

        IF NOT v_belongs THEN
            RAISE EXCEPTION 'LTQ11: Question % is not part of attempt %.', p_question_id, p_attempt_id
                USING ERRCODE = 'LTQ11';
        END IF;

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
        IF SQLSTATE IN ('LTQ07', 'LTQ01', 'LTQ09', 'LTQ11') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_answer_quiz_question unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while saving the answer: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

-- 6. Ensure passing a FINAL quiz completes the enrollment (and thus satisfies prerequisites)
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
    v_quiz_type   VARCHAR(20);
    v_quiz_id     BIGINT;
BEGIN
    IF p_bypass_quiz THEN
        SELECT ba.id, ba.user_id, ba.target_course_id, ba.prerequisite_course_id, ba.status
        INTO attempt_id, v_user_id, v_target, v_prereq, status
        FROM public.bypass_attempts ba
        WHERE ba.id = p_attempt_id;
    ELSE
        SELECT qa.id, qa.enrollment_id, qa.status, qa.quiz_id
        INTO attempt_id, v_enrollment, status, v_quiz_id
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
        SELECT q.passing_score, q.quiz_type
        INTO v_passing, v_quiz_type
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

        -- If this quiz is a FINAL assessment and passed, mark enrollment completed
        IF v_passed AND v_quiz_type = 'FINAL' THEN
            UPDATE public.enrollments e
            SET status = 'completed',
                completed_at = COALESCE(e.completed_at, CURRENT_TIMESTAMP)
            FROM public.quiz_attempts qa
            WHERE qa.id = p_attempt_id
              AND e.id = qa.enrollment_id;
        END IF;
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

-- 7. Adjust course progress function to respect FINAL assessments
CREATE OR REPLACE FUNCTION public.fn_update_course_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_enrollment_id BIGINT;
    v_progress      NUMERIC(5,2);
    v_status        VARCHAR(20);
    v_has_final     BOOLEAN;
BEGIN
    v_enrollment_id := COALESCE(NEW.enrollment_id, OLD.enrollment_id);

    v_progress := public.fn_calculate_course_progress(v_enrollment_id);

    SELECT status
    INTO v_status
    FROM public.enrollments
    WHERE id = v_enrollment_id;

    -- Does the course have an active final assessment?
    SELECT EXISTS (
        SELECT 1 FROM public.quizzes q
        WHERE q.course_id = (
            SELECT course_id FROM public.enrollments WHERE id = v_enrollment_id
        )
          AND q.quiz_type = 'FINAL'
          AND q.is_active = TRUE
    ) INTO v_has_final;

    IF v_status = 'active' AND v_progress >= 100 THEN
        IF v_has_final THEN
            -- Keep enrollment active but set progress to 100
            UPDATE public.enrollments
            SET progress_pct = v_progress
            WHERE id = v_enrollment_id;
        ELSE
            -- Legacy behavior: mark completed
            UPDATE public.enrollments
            SET progress_pct = v_progress,
                status = 'completed',
                completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP)
            WHERE id = v_enrollment_id;
        END IF;
    ELSIF v_status = 'active' OR v_progress < 100 THEN
        UPDATE public.enrollments
        SET progress_pct = v_progress
        WHERE id = v_enrollment_id
          AND progress_pct <> v_progress;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- 8. Publication validation: when publishing a course, ensure final assessment exists and is valid
CREATE OR REPLACE FUNCTION public.fn_validate_course_publish()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_has_final BOOLEAN;
    v_valid_questions INTEGER;
BEGIN
    -- Only validate when changing to published
    IF (TG_OP = 'UPDATE') THEN
        IF NOT (NEW.status = 'published' AND OLD.status IS DISTINCT FROM 'published') THEN
            RETURN NEW;
        END IF;
    ELSE
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.quizzes q
        WHERE q.course_id = NEW.id
          AND q.quiz_type = 'FINAL'
          AND q.is_active = TRUE
    ) INTO v_has_final;

    IF NOT v_has_final THEN
        RAISE EXCEPTION 'LTQ10: Course % cannot be published without an active final assessment.', NEW.id
            USING ERRCODE = 'LTQ10';
    END IF;

    -- Check there are at least 10 valid questions
    SELECT COUNT(*)
    INTO v_valid_questions
    FROM public.quiz_questions qq
    JOIN public.quizzes q ON q.id = qq.quiz_id
    WHERE q.course_id = NEW.id
      AND q.quiz_type = 'FINAL'
      AND (
          SELECT COUNT(*) FROM public.quiz_options qo WHERE qo.question_id = qq.id
      ) >= 2
      AND (
          SELECT COUNT(*) FILTER (WHERE qo2.is_correct) FROM public.quiz_options qo2 WHERE qo2.question_id = qq.id
      ) = 1;

    IF v_valid_questions < 10 THEN
        RAISE EXCEPTION 'LTQ12: Final assessment for course % does not contain at least 10 valid questions.', NEW.id
            USING ERRCODE = 'LTQ12';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_course_publish ON public.courses;
CREATE TRIGGER trg_validate_course_publish
BEFORE UPDATE OF status ON public.courses
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_course_publish();

-- 9. Safe backfill: for existing quizzes, try to set course_id for lesson-linked quizzes
-- (best-effort, non-fatal)
DO $$
BEGIN
    -- If any quiz has lesson_id and the lesson exists, copy its course_id
    UPDATE public.quizzes q
    SET course_id = l.course_id
    FROM public.lessons l
    WHERE q.course_id IS NULL
      AND q.lesson_id = l.id;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'V15 backfill encountered an error: %', SQLERRM;
END;
$$;
