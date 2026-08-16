-- ==========================================================================
-- V27: Lesson quiz API (single-call student flow + instructor bank CRUD)
--
-- The student frontend (quiz-attempt.html / quizEditor.js) is STATELESS:
--   * GET  /quizzes/lesson/{lesson}/status   -> pass state + daily attempts
--   * GET  /quizzes/lesson/{lesson}/random   -> N random questions (id/text/options)
--   * POST /progress/{course}/lessons/{lesson}/quiz {answers, bypass}
--   * GET/POST /quizzes/lesson/{lesson}      -> instructor bank read/create
--   * GET/PUT/DELETE /quizzes/{id}           -> instructor bank item
--
-- Every rule lives in the database (project convention). The submit call
-- grades the questions the student actually saw (the ids come back from
-- /random, so no snapshot mismatch is possible) and:
--   * regular mode : requires an ACTIVE enrollment, enforces the quiz's
--                    daily attempt limit, records quiz_attempts /
--                    attempt_answers / quiz_submissions, keeps the best
--                    score on enrollments.final_score_pct, and on a PASS
--                    marks the lesson completed and unlocks the next one.
--   * bypass mode  : requires NO enrollment. Passing the lesson quiz of a
--                    prerequisite course inserts course_bypasses rows for
--                    every course that directly requires that prerequisite
--                    and still blocks the user (V9's trigger then unlocks
--                    the enrolled targets' first lessons).
--
-- Also fixes a latent V24 issue: quizzes.lesson_id was declared NOT NULL in
-- V10 but V24's sp_final_assessment_upsert inserts lesson_id = NULL for
-- course-level FINAL quizzes. Dropping NOT NULL makes the final-assessment
-- upsert legal (the chk_quizzes_final_course_not_null check still guards it).
-- ==========================================================================

-- ==========================================================================
-- 0. Allow course-level FINAL quizzes (latent V24 fix)
-- ==========================================================================

ALTER TABLE public.quizzes
    ALTER COLUMN lesson_id DROP NOT NULL;

-- ==========================================================================
-- 1. Lesson / quiz resolution helper
-- ==========================================================================

CREATE OR REPLACE FUNCTION public.fn_resolve_lesson_quiz(
    p_actor_id BIGINT,
    p_lesson   VARCHAR,
    p_bypass   BOOLEAN,
    p_course   VARCHAR DEFAULT NULL
)
RETURNS TABLE (quiz_id BIGINT, lesson_id BIGINT, course_id BIGINT)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_lesson_key VARCHAR;
    v_course_id  BIGINT;
BEGIN
    v_lesson_key := LOWER(BTRIM(COALESCE(p_lesson, '')));

    -- Optional course filter: numeric id or slug. Disambiguates the same
    -- lesson title appearing in several courses (editor -> numeric id,
    -- student -> course slug).
    IF COALESCE(BTRIM(p_course), '') <> '' THEN
        IF p_course ~ '^\d+$' THEN
            v_course_id := p_course::BIGINT;
        ELSE
            SELECT c.id INTO v_course_id
            FROM public.courses c
            WHERE c.slug = BTRIM(p_course);
        END IF;
    END IF;

    RETURN QUERY
    SELECT q.id, l.id, l.course_id
    FROM public.lessons l
    LEFT JOIN public.quizzes q
           ON q.lesson_id = l.id
          AND q.quiz_type = 'LESSON'
          AND q.is_active = TRUE
    WHERE (
            LOWER(REGEXP_REPLACE(BTRIM(l.title), '[^a-zA-Z0-9]+', '-', 'g')) = v_lesson_key
         OR LOWER(BTRIM(l.title)) = v_lesson_key
         OR l.id::TEXT = v_lesson_key
          )
      AND (v_course_id IS NULL OR l.course_id = v_course_id)
    ORDER BY
        -- For the student flow prefer a lesson inside a course the actor is
        -- actively enrolled in (keeps attempt counters unambiguous).
        (CASE
            WHEN p_bypass = TRUE THEN 0
            WHEN EXISTS (
                SELECT 1 FROM public.enrollments e
                WHERE e.user_id = p_actor_id
                  AND e.course_id = l.course_id
                  AND e.status = 'active'
            ) THEN 0
            ELSE 1
         END),
        l.course_id ASC,
        l.sequence_order ASC,
        l.id ASC
    LIMIT 1;
END;
$$;

-- ==========================================================================
-- 2. Status: pass state + remaining daily attempts
-- ==========================================================================

CREATE OR REPLACE FUNCTION public.fn_lesson_quiz_status(
    p_actor_id BIGINT,
    p_lesson   VARCHAR,
    p_bypass   BOOLEAN,
    p_course   VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    passed        BOOLEAN,
    used          INTEGER,
    attempts_left INTEGER,
    "limit" INTEGER,
    exhausted     BOOLEAN,
    quiz_id       BIGINT,
    lesson_id     BIGINT,
    course_id     BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_quiz_id   BIGINT;
    v_lesson_id BIGINT;
    v_course_id BIGINT;
    v_limit     INTEGER;
    v_used      INTEGER;
    v_passed    BOOLEAN;
BEGIN
    SELECT r.quiz_id, r.lesson_id, r.course_id
    INTO v_quiz_id, v_lesson_id, v_course_id
    FROM public.fn_resolve_lesson_quiz(p_actor_id, p_lesson, p_bypass, p_course) r;

    IF v_lesson_id IS NULL THEN
        RAISE EXCEPTION 'LTQ15: No lesson quiz found for lesson %', p_lesson
            USING ERRCODE = 'LTQ15';
    END IF;

    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ15: Lesson % has no active lesson quiz yet.', p_lesson
            USING ERRCODE = 'LTQ15';
    END IF;

    SELECT q.daily_attempt_limit
    INTO v_limit
    FROM public.quizzes q
    WHERE q.id = v_quiz_id;
    v_limit := COALESCE(v_limit, 3);

    IF p_bypass THEN
        v_passed := EXISTS (
            SELECT 1 FROM public.course_bypasses cb
            WHERE cb.user_id = p_actor_id
              AND cb.prerequisite_course_id = v_course_id
        );
        SELECT COUNT(*) INTO v_used
        FROM public.bypass_attempts ba
        WHERE ba.user_id = p_actor_id
          AND ba.prerequisite_course_id = v_course_id
          AND ba.attempt_date = CURRENT_DATE;
    ELSE
        v_passed := EXISTS (
            SELECT 1 FROM public.lesson_progress lp
            JOIN public.enrollments e ON e.id = lp.enrollment_id
            WHERE e.user_id = p_actor_id
              AND e.course_id = v_course_id
              AND lp.lesson_id = v_lesson_id
              AND lp.status = 'completed'
        );
        SELECT COUNT(*) INTO v_used
        FROM public.quiz_attempts qa
        JOIN public.enrollments e ON e.id = qa.enrollment_id
        WHERE e.user_id = p_actor_id
          AND e.course_id = v_course_id
          AND qa.quiz_id = v_quiz_id
          AND qa.attempt_date = CURRENT_DATE;
    END IF;

    v_used := COALESCE(v_used, 0);

    passed        := v_passed;
    used          := v_used;
    attempts_left := GREATEST(0, v_limit - v_used);
    "limit" := v_limit;
    exhausted     := v_used >= v_limit;
    quiz_id       := v_quiz_id;
    lesson_id     := v_lesson_id;
    course_id     := v_course_id;
    RETURN NEXT;
    RETURN;
END;
$$;

-- ==========================================================================
-- 3. Random questions for a student attempt
-- (sanitized: question id + text + options, never the is_correct flag)
-- ==========================================================================

CREATE OR REPLACE FUNCTION public.fn_lesson_quiz_questions(
    p_actor_id BIGINT,
    p_lesson   VARCHAR,
    p_bypass   BOOLEAN,
    p_count    INTEGER,
    p_course   VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    question_id   BIGINT,
    question_text VARCHAR,
    option_id     BIGINT,
    option_label  VARCHAR(5),
    option_text   VARCHAR
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_quiz_id BIGINT;
BEGIN
    SELECT r.quiz_id
    INTO v_quiz_id
    FROM public.fn_resolve_lesson_quiz(p_actor_id, p_lesson, p_bypass, p_course) r;

    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ15: Lesson % has no active lesson quiz yet.', p_lesson
            USING ERRCODE = 'LTQ15';
    END IF;

    RETURN QUERY
    SELECT pick.question_id, qq.question_text, qo.id, qo.option_label, qo.option_text
    FROM public.fn_quiz_pick_questions(v_quiz_id, p_count) pick
    JOIN public.quiz_questions qq ON qq.id = pick.question_id
    JOIN public.quiz_options qo ON qo.question_id = qq.id
    ORDER BY pick.question_id ASC, qo.option_label ASC;
END;
$$;

-- ==========================================================================
-- 4. Single-call submit: grade, persist, complete lesson / clear bypass
-- ==========================================================================

CREATE OR REPLACE FUNCTION public.sp_submit_lesson_quiz(
    p_actor_id BIGINT,
    p_lesson   VARCHAR,
    p_bypass   BOOLEAN,
    p_answers  JSONB,
    p_course   VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    score_pct      NUMERIC(5,2),
    passed         BOOLEAN,
    already_passed BOOLEAN,
    attempts_left  INTEGER,
    exhausted      BOOLEAN,
    correct_answers JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz_id      BIGINT;
    v_lesson_id    BIGINT;
    v_course_id    BIGINT;
    v_limit        INTEGER;
    v_enrollment   BIGINT;
    v_total        INTEGER;
    v_correct      INTEGER;
    v_score        NUMERIC(5,2);
    v_passed       BOOLEAN;
    v_attempt_no   INTEGER;
    v_attempt_id   BIGINT;
    v_answer       JSONB;
    v_question_id  BIGINT;
    v_selected     VARCHAR;
    v_option_id    BIGINT;
    v_is_correct   BOOLEAN;
    v_used         INTEGER;
    v_target       BIGINT;
    v_targets      BIGINT[];
BEGIN
    SELECT r.quiz_id, r.lesson_id, r.course_id
    INTO v_quiz_id, v_lesson_id, v_course_id
    FROM public.fn_resolve_lesson_quiz(p_actor_id, p_lesson, p_bypass, p_course) r;

    IF v_lesson_id IS NULL OR v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ15: Lesson % has no active lesson quiz yet.', p_lesson
            USING ERRCODE = 'LTQ15';
    END IF;

    SELECT q.daily_attempt_limit
    INTO v_limit
    FROM public.quizzes q
    WHERE q.id = v_quiz_id;
    v_limit := COALESCE(v_limit, 3);

    IF p_bypass THEN
        -- Targets: every course that directly requires this quiz's course
        -- and still blocks the actor (fn_prerequisite_satisfied uses the
        -- per-prerequisite required_min_score from V25).
        SELECT ARRAY(
            SELECT cp.course_id
            FROM public.course_prerequisites cp
            WHERE cp.prerequisite_course_id = v_course_id
              AND NOT public.fn_prerequisite_satisfied(p_actor_id, cp.course_id)
            ORDER BY cp.course_id
        ) INTO v_targets;

        IF v_targets IS NULL OR array_length(v_targets, 1) IS NULL THEN
            RAISE EXCEPTION 'LTQ20: No course is blocked by the % prerequisite.', p_lesson
                USING ERRCODE = 'LTQ20';
        END IF;

        IF EXISTS (
            SELECT 1 FROM public.course_bypasses cb
            WHERE cb.user_id = p_actor_id
              AND cb.prerequisite_course_id = v_course_id
        ) THEN
            score_pct      := NULL;
            passed         := TRUE;
            already_passed := TRUE;
            attempts_left  := 0;
            exhausted      := FALSE;
            correct_answers := '[]'::JSONB;
            RETURN NEXT;
            RETURN;
        END IF;

        SELECT COUNT(*) INTO v_used
        FROM public.bypass_attempts ba
        WHERE ba.user_id = p_actor_id
          AND ba.prerequisite_course_id = v_course_id
          AND ba.attempt_date = CURRENT_DATE;
    ELSE
        SELECT e.id INTO v_enrollment
        FROM public.enrollments e
        WHERE e.user_id = p_actor_id
          AND e.course_id = v_course_id
          AND e.status = 'active';

        IF v_enrollment IS NULL THEN
            RAISE EXCEPTION 'LTQ19: You are not actively enrolled in this course.'
                USING ERRCODE = 'LTQ19';
        END IF;

        IF EXISTS (
            SELECT 1 FROM public.lesson_progress lp
            WHERE lp.enrollment_id = v_enrollment
              AND lp.lesson_id = v_lesson_id
              AND lp.status = 'completed'
        ) THEN
            score_pct      := NULL;
            passed         := TRUE;
            already_passed := TRUE;
            attempts_left  := 0;
            exhausted      := FALSE;
            correct_answers := '[]'::JSONB;
            RETURN NEXT;
            RETURN;
        END IF;

        SELECT COUNT(*) INTO v_used
        FROM public.quiz_attempts qa
        WHERE qa.enrollment_id = v_enrollment
          AND qa.quiz_id = v_quiz_id
          AND qa.attempt_date = CURRENT_DATE;
    END IF;

    v_used := COALESCE(v_used, 0);

    IF v_used >= v_limit THEN
        RAISE EXCEPTION 'LTQ04: Daily attempt limit for this quiz was reached.'
            USING ERRCODE = 'LTQ04';
    END IF;

    IF p_answers IS NULL OR jsonb_array_length(p_answers) = 0 THEN
        RAISE EXCEPTION 'LTQ06: No answers were provided.'
            USING ERRCODE = 'LTQ06';
    END IF;

    -- Grade against the questions the student actually saw (ids from /random).
    v_total := jsonb_array_length(p_answers);
    v_correct := 0;

    FOR v_answer IN SELECT value FROM jsonb_array_elements(p_answers) LOOP
        v_question_id := NULLIF((v_answer->>'id')::TEXT, '')::BIGINT;
        v_selected    := UPPER(BTRIM(COALESCE(v_answer->>'selected', '')));

        IF v_question_id IS NULL THEN
            RAISE EXCEPTION 'LTQ18: An answer with no question id was submitted.'
                USING ERRCODE = 'LTQ18';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM public.quiz_questions qq
            WHERE qq.id = v_question_id AND qq.quiz_id = v_quiz_id
        ) THEN
            RAISE EXCEPTION 'LTQ16: Question % does not belong to this quiz.', v_question_id
                USING ERRCODE = 'LTQ16';
        END IF;

        IF v_selected = '' THEN
            RAISE EXCEPTION 'LTQ18: An answer with no selection was submitted.'
                USING ERRCODE = 'LTQ18';
        END IF;

        SELECT qo.id, qo.is_correct
        INTO v_option_id, v_is_correct
        FROM public.quiz_options qo
        WHERE qo.question_id = v_question_id
          AND UPPER(qo.option_label) = v_selected;

        IF v_option_id IS NULL THEN
            RAISE EXCEPTION 'LTQ18: Invalid option % selected for question %.', v_selected, v_question_id
                USING ERRCODE = 'LTQ18';
        END IF;

        IF v_is_correct THEN
            v_correct := v_correct + 1;
        END IF;
    END LOOP;

    v_score  := ROUND((v_correct::NUMERIC / v_total::NUMERIC) * 100, 2);
    v_passed := v_score >= (
        SELECT COALESCE(q.passing_score, 60.00) FROM public.quizzes q WHERE q.id = v_quiz_id
    );

    IF p_bypass THEN
        -- One bypass attempt row per target (V10 table contract).
        FOR v_target IN SELECT unnest(v_targets) LOOP
            SELECT COALESCE(MAX(attempt_no), 0) + 1
            INTO v_attempt_no
            FROM public.bypass_attempts
            WHERE user_id = p_actor_id
              AND target_course_id = v_target
              AND prerequisite_course_id = v_course_id
              AND attempt_date = CURRENT_DATE;

            INSERT INTO public.bypass_attempts (
                user_id, target_course_id, prerequisite_course_id, attempt_date, attempt_no
            )
            VALUES (p_actor_id, v_target, v_course_id, CURRENT_DATE, v_attempt_no)
            RETURNING id INTO v_attempt_id;

            INSERT INTO public.bypass_attempt_questions (attempt_id, source_question_id)
            SELECT v_attempt_id, (t.v_answer->>'id')::BIGINT
            FROM jsonb_array_elements(p_answers) AS t(v_answer);

            INSERT INTO public.bypass_attempt_answers (
                attempt_id, source_question_id, selected_option_id, is_correct
            )
            SELECT v_attempt_id, (t.v_answer->>'id')::BIGINT, qo.id, qo.is_correct
            FROM jsonb_array_elements(p_answers) AS t(v_answer)
            JOIN public.quiz_options qo
              ON qo.question_id = (t.v_answer->>'id')::BIGINT
             AND UPPER(qo.option_label) = UPPER(BTRIM(COALESCE(t.v_answer->>'selected', '')));

            UPDATE public.bypass_attempts
            SET status = 'submitted',
                submitted_at = CURRENT_TIMESTAMP,
                score_pct = v_score,
                passed = v_passed
            WHERE id = v_attempt_id;
        END LOOP;

        IF v_passed THEN
            -- Clears the prerequisite for every blocked target course.
            INSERT INTO public.course_bypasses (user_id, target_course_id, prerequisite_course_id)
            SELECT p_actor_id, unnest(v_targets), v_course_id
            ON CONFLICT (user_id, target_course_id, prerequisite_course_id) DO NOTHING;
        END IF;
    ELSE
        SELECT COALESCE(MAX(attempt_no), 0) + 1
        INTO v_attempt_no
        FROM public.quiz_attempts
        WHERE enrollment_id = v_enrollment
          AND quiz_id = v_quiz_id
          AND attempt_date = CURRENT_DATE;

        INSERT INTO public.quiz_attempts (enrollment_id, quiz_id, attempt_date, attempt_no)
        VALUES (v_enrollment, v_quiz_id, CURRENT_DATE, v_attempt_no)
        RETURNING id INTO v_attempt_id;

        INSERT INTO public.quiz_attempt_questions (attempt_id, question_id, display_order)
        SELECT v_attempt_id, (t.v_answer->>'id')::BIGINT, t.ord
        FROM jsonb_array_elements(p_answers) WITH ORDINALITY AS t(v_answer, ord);

        INSERT INTO public.attempt_answers (attempt_id, question_id, selected_option_id, is_correct)
        SELECT v_attempt_id, (t.v_answer->>'id')::BIGINT, qo.id, qo.is_correct
        FROM jsonb_array_elements(p_answers) AS t(v_answer)
        JOIN public.quiz_options qo
          ON qo.question_id = (t.v_answer->>'id')::BIGINT
         AND UPPER(qo.option_label) = UPPER(BTRIM(COALESCE(t.v_answer->>'selected', '')));

        UPDATE public.quiz_attempts
        SET status = 'submitted',
            submitted_at = CURRENT_TIMESTAMP,
            score_pct = v_score,
            passed = v_passed
        WHERE id = v_attempt_id;

        INSERT INTO public.quiz_submissions (user_id, quiz_id, score_pct, passed)
        VALUES (p_actor_id, v_quiz_id, v_score, v_passed);

        -- Keep the best score on the enrollment (V25 reads this for the
        -- prerequisite min-score gate).
        UPDATE public.enrollments
        SET final_score_pct = GREATEST(COALESCE(final_score_pct, v_score), v_score)
        WHERE id = v_enrollment;

        IF v_passed THEN
            UPDATE public.lesson_progress
            SET status = 'completed',
                completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP)
            WHERE enrollment_id = v_enrollment
              AND lesson_id = v_lesson_id
              AND status <> 'completed';

            -- Unlock the next lesson in the course (same as the mock).
            UPDATE public.lesson_progress lp
            SET status = 'unlocked',
                unlocked_at = COALESCE(lp.unlocked_at, CURRENT_TIMESTAMP)
            WHERE lp.enrollment_id = v_enrollment
              AND lp.status = 'locked'
              AND lp.lesson_id = (
                  SELECT n.id
                  FROM public.lessons n
                  WHERE n.course_id = v_course_id
                    AND n.sequence_order > (
                        SELECT l.sequence_order FROM public.lessons l WHERE l.id = v_lesson_id
                    )
                  ORDER BY n.sequence_order ASC, n.id ASC
                  LIMIT 1
              );
        END IF;
    END IF;

    score_pct := v_score;
    passed    := v_passed;
    already_passed := FALSE;
    attempts_left  := GREATEST(0, v_limit - v_used - 1);
    exhausted      := (v_used + 1) >= v_limit;

    IF v_passed THEN
        correct_answers := COALESCE(
            (SELECT jsonb_agg(
                        jsonb_build_object('id', qq.id, 'correct', qo.option_label)
                        ORDER BY qq.id ASC)
             FROM public.quiz_questions qq
             JOIN public.quiz_options qo
               ON qo.question_id = qq.id AND qo.is_correct = TRUE
             WHERE qq.quiz_id = v_quiz_id),
            '[]'::JSONB
        );
    ELSE
        correct_answers := '[]'::JSONB;
    END IF;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTQ04', 'LTQ06', 'LTQ15', 'LTQ16', 'LTQ18', 'LTQ19', 'LTQ20', '23505', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_submit_lesson_quiz unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while submitting the lesson quiz: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

-- ==========================================================================
-- 5. Instructor bank: list, create, update, delete (gated by
--    fn_require_course_manager so only the course owner / admin can edit)
-- ==========================================================================

CREATE OR REPLACE FUNCTION public.fn_lesson_quiz_bank(
    p_actor_id BIGINT,
    p_lesson   VARCHAR,
    p_course   VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    question_id    BIGINT,
    question_text  VARCHAR,
    sequence_order INTEGER,
    option_id      BIGINT,
    option_label   VARCHAR(5),
    option_text    VARCHAR,
    is_correct     BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_lesson_id BIGINT;
    v_course_id BIGINT;
BEGIN
    SELECT r.lesson_id, r.course_id
    INTO v_lesson_id, v_course_id
    FROM public.fn_resolve_lesson_quiz(p_actor_id, p_lesson, FALSE, p_course) r;

    IF v_lesson_id IS NULL THEN
        RAISE EXCEPTION 'LTQ15: No lesson found for %', p_lesson
            USING ERRCODE = 'LTQ15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    RETURN QUERY
    SELECT qq.id, qq.question_text, qq.sequence_order,
           qo.id, qo.option_label, qo.option_text, qo.is_correct
    FROM public.quiz_questions qq
    JOIN public.quizzes q
      ON q.id = qq.quiz_id
     AND q.quiz_type = 'LESSON'
     AND q.lesson_id = v_lesson_id
    LEFT JOIN public.quiz_options qo ON qo.question_id = qq.id
    ORDER BY qq.sequence_order ASC, qq.id ASC, qo.option_label ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_lesson_quiz_question_create(
    p_actor_id BIGINT,
    p_lesson   VARCHAR,
    p_text     VARCHAR,
    p_options  JSONB,
    p_correct  VARCHAR,
    p_course   VARCHAR DEFAULT NULL
)
RETURNS TABLE (question_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_lesson_id  BIGINT;
    v_course_id  BIGINT;
    v_quiz_id    BIGINT;
    v_opt_count  INTEGER;
    v_label      VARCHAR(1);
    v_index      INTEGER;
    v_question_id BIGINT;
BEGIN
    SELECT r.lesson_id, r.course_id
    INTO v_lesson_id, v_course_id
    FROM public.fn_resolve_lesson_quiz(p_actor_id, p_lesson, FALSE, p_course) r;

    IF v_lesson_id IS NULL THEN
        RAISE EXCEPTION 'LTQ15: No lesson found for %', p_lesson
            USING ERRCODE = 'LTQ15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    -- Ensure a lesson quiz exists (create on first question).
    SELECT q.id INTO v_quiz_id
    FROM public.quizzes q
    WHERE q.lesson_id = v_lesson_id AND q.quiz_type = 'LESSON';

    IF v_quiz_id IS NULL THEN
        INSERT INTO public.quizzes (lesson_id, course_id, title, passing_score, questions_per_attempt, daily_attempt_limit)
        SELECT v_lesson_id, v_course_id, l.title, 60.00, 5, 3
        FROM public.lessons l
        WHERE l.id = v_lesson_id
        ON CONFLICT (lesson_id) DO NOTHING
        RETURNING id INTO v_quiz_id;
    END IF;

    IF v_quiz_id IS NULL THEN
        SELECT id INTO v_quiz_id
        FROM public.quizzes
        WHERE lesson_id = v_lesson_id AND quiz_type = 'LESSON';
    END IF;

    IF (SELECT COUNT(*) FROM public.quiz_questions qq WHERE qq.quiz_id = v_quiz_id) >= 20 THEN
        RAISE EXCEPTION 'LTQ17: The question bank for this lesson is full (max 20).'
            USING ERRCODE = 'LTQ17';
    END IF;

    IF BTRIM(COALESCE(p_text, '')) = '' THEN
        RAISE EXCEPTION 'LTQ18: Question text is required.'
            USING ERRCODE = 'LTQ18';
    END IF;

    IF p_options IS NULL
       OR jsonb_array_length(p_options) < 2
       OR jsonb_array_length(p_options) > 6 THEN
        RAISE EXCEPTION 'LTQ18: A question needs between 2 and 6 options.'
            USING ERRCODE = 'LTQ18';
    END IF;

    v_opt_count := jsonb_array_length(p_options);

    FOR v_index IN 1 .. v_opt_count LOOP
        IF BTRIM(p_options->>(v_index - 1)) = '' THEN
            RAISE EXCEPTION 'LTQ18: Option text cannot be empty.'
                USING ERRCODE = 'LTQ18';
        END IF;
    END LOOP;

    v_label := UPPER(BTRIM(COALESCE(p_correct, '')));

    IF v_label = ''
       OR ASCII(v_label) < ASCII('A')
       OR ASCII(v_label) > ASCII('A') + v_opt_count - 1 THEN
        RAISE EXCEPTION 'LTQ18: Correct answer must be one of A-%.', CHR(ASCII('A') + v_opt_count - 1)
            USING ERRCODE = 'LTQ18';
    END IF;

    INSERT INTO public.quiz_questions (quiz_id, question_text, sequence_order)
    VALUES (
        v_quiz_id,
        BTRIM(p_text),
        (SELECT COALESCE(MAX(sequence_order), 0) + 1
         FROM public.quiz_questions qq WHERE qq.quiz_id = v_quiz_id)
    )
    RETURNING id INTO v_question_id;

    INSERT INTO public.quiz_options (question_id, option_label, option_text, is_correct)
    SELECT v_question_id, CHR(64 + ord), BTRIM(opt_text), (CHR(64 + ord) = v_label)
    FROM jsonb_array_elements_text(p_options) WITH ORDINALITY AS t(opt_text, ord);

    question_id := v_question_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTQ15', 'LTQ17', 'LTQ18', 'LTC10', 'LTC11', '23505', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_lesson_quiz_question_create unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while creating the question: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_lesson_quiz_question_update(
    p_actor_id    BIGINT,
    p_question_id BIGINT,
    p_text        VARCHAR,
    p_options     JSONB,
    p_correct     VARCHAR
)
RETURNS TABLE (question_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz_id   BIGINT;
    v_course_id BIGINT;
    v_opt_count INTEGER;
    v_label     VARCHAR(1);
    v_index     INTEGER;
BEGIN
    SELECT qq.quiz_id, q.course_id
    INTO v_quiz_id, v_course_id
    FROM public.quiz_questions qq
    JOIN public.quizzes q ON q.id = qq.quiz_id
    WHERE qq.id = p_question_id;

    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ16: Question % does not exist.', p_question_id
            USING ERRCODE = 'LTQ16';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF BTRIM(COALESCE(p_text, '')) = '' THEN
        RAISE EXCEPTION 'LTQ18: Question text is required.'
            USING ERRCODE = 'LTQ18';
    END IF;

    IF p_options IS NULL
       OR jsonb_array_length(p_options) < 2
       OR jsonb_array_length(p_options) > 6 THEN
        RAISE EXCEPTION 'LTQ18: A question needs between 2 and 6 options.'
            USING ERRCODE = 'LTQ18';
    END IF;

    v_opt_count := jsonb_array_length(p_options);

    FOR v_index IN 1 .. v_opt_count LOOP
        IF BTRIM(p_options->>(v_index - 1)) = '' THEN
            RAISE EXCEPTION 'LTQ18: Option text cannot be empty.'
                USING ERRCODE = 'LTQ18';
        END IF;
    END LOOP;

    v_label := UPPER(BTRIM(COALESCE(p_correct, '')));

    IF v_label = ''
       OR ASCII(v_label) < ASCII('A')
       OR ASCII(v_label) > ASCII('A') + v_opt_count - 1 THEN
        RAISE EXCEPTION 'LTQ18: Correct answer must be one of A-%.', CHR(ASCII('A') + v_opt_count - 1)
            USING ERRCODE = 'LTQ18';
    END IF;

    UPDATE public.quiz_questions
    SET question_text = BTRIM(p_text)
    WHERE id = p_question_id;

    DELETE FROM public.quiz_options WHERE question_id = p_question_id;

    INSERT INTO public.quiz_options (question_id, option_label, option_text, is_correct)
    SELECT p_question_id, CHR(64 + ord), BTRIM(opt_text), (CHR(64 + ord) = v_label)
    FROM jsonb_array_elements_text(p_options) WITH ORDINALITY AS t(opt_text, ord);

    question_id := p_question_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTQ16', 'LTQ18', 'LTC10', 'LTC11', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_lesson_quiz_question_update unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the question: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_lesson_quiz_question_delete(
    p_actor_id    BIGINT,
    p_question_id BIGINT
)
RETURNS TABLE (question_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz_id   BIGINT;
    v_course_id BIGINT;
BEGIN
    SELECT qq.quiz_id, q.course_id
    INTO v_quiz_id, v_course_id
    FROM public.quiz_questions qq
    JOIN public.quizzes q ON q.id = qq.quiz_id
    WHERE qq.id = p_question_id;

    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ16: Question % does not exist.', p_question_id
            USING ERRCODE = 'LTQ16';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    DELETE FROM public.quiz_options WHERE question_id = p_question_id;
    DELETE FROM public.quiz_questions WHERE id = p_question_id;

    question_id := p_question_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTQ16', 'LTC10', 'LTC11', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_lesson_quiz_question_delete unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while deleting the question: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
