-- V24: Final assessment authoritative DB functions (wrappers and instructor APIs)
-- All business logic for final assessments is implemented in PostgreSQL.

-- 1. fn_final_assessment_get(p_actor_user_id, p_course_id)
CREATE OR REPLACE FUNCTION public.fn_final_assessment_get(
    p_actor_user_id BIGINT,
    p_course_id     BIGINT
)
RETURNS TABLE (
    quiz_id BIGINT,
    title VARCHAR,
    passing_score NUMERIC(5,2),
    questions_per_attempt INTEGER,
    daily_attempt_limit INTEGER,
    is_active BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz public.quizzes%ROWTYPE;
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_user_id);

    SELECT id, title, passing_score, questions_per_attempt, daily_attempt_limit, is_active
    INTO v_quiz
    FROM public.quizzes
    WHERE course_id = p_course_id
      AND quiz_type = 'FINAL'
    LIMIT 1;

    IF v_quiz.id IS NULL THEN
        RETURN;
    END IF;

    quiz_id := v_quiz.id;
    title := v_quiz.title;
    passing_score := v_quiz.passing_score;
    questions_per_attempt := v_quiz.questions_per_attempt;
    daily_attempt_limit := v_quiz.daily_attempt_limit;
    is_active := v_quiz.is_active;
    RETURN NEXT;
    RETURN;
END;
$$;

-- 2. sp_final_assessment_upsert(p_actor_user_id, p_course_id, p_title, p_passing_score, p_daily_attempt_limit, p_is_active)
CREATE OR REPLACE FUNCTION public.sp_final_assessment_upsert(
    p_actor_user_id BIGINT,
    p_course_id BIGINT,
    p_title VARCHAR,
    p_passing_score NUMERIC,
    p_daily_attempt_limit INTEGER,
    p_is_active BOOLEAN
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz_id BIGINT;
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_user_id);

    SELECT id INTO v_quiz_id FROM public.quizzes WHERE course_id = p_course_id AND quiz_type = 'FINAL' LIMIT 1;

    IF v_quiz_id IS NOT NULL THEN
        UPDATE public.quizzes
        SET title = COALESCE(p_title, title),
            passing_score = COALESCE(p_passing_score, passing_score),
            daily_attempt_limit = COALESCE(p_daily_attempt_limit, daily_attempt_limit),
            is_active = COALESCE(p_is_active, is_active),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_quiz_id;
        RETURN v_quiz_id;
    ELSE
        INSERT INTO public.quizzes (lesson_id, course_id, title, passing_score, questions_per_attempt, daily_attempt_limit, quiz_type, is_active)
        VALUES (NULL, p_course_id, p_title, COALESCE(p_passing_score, 60.00), 10, COALESCE(p_daily_attempt_limit, 3), 'FINAL', COALESCE(p_is_active, true))
        RETURNING id INTO v_quiz_id;
        RETURN v_quiz_id;
    END IF;
END;
$$;

-- 3. fn_final_assessment_questions(p_actor_user_id, p_assessment_id)
-- Returns instructor view of question bank with correct answer flags
CREATE OR REPLACE FUNCTION public.fn_final_assessment_questions(
    p_actor_user_id BIGINT,
    p_assessment_id BIGINT
)
RETURNS TABLE (question_id BIGINT, question_text TEXT, options JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
BEGIN
    SELECT course_id INTO v_course_id FROM public.quizzes WHERE id = p_assessment_id AND quiz_type = 'FINAL';
    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Assessment % does not exist or is not FINAL.', p_assessment_id USING ERRCODE = 'LTQ03';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_user_id);

    RETURN QUERY
    SELECT qq.id, qq.question_text,
        COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT('option_id', qo.id, 'option_text', qo.option_text, 'is_correct', qo.is_correct, 'option_label', qo.option_label) ORDER BY qo.option_label) FILTER (WHERE qo.id IS NOT NULL), '[]'::JSONB)
    FROM public.quiz_questions qq
    LEFT JOIN public.quiz_options qo ON qo.question_id = qq.id
    WHERE qq.quiz_id = p_assessment_id
    GROUP BY qq.id, qq.question_text
    ORDER BY qq.id;
END;
$$;

-- 4. sp_final_assessment_question_create(p_actor_user_id, p_assessment_id, p_question_text, p_options_jsonb)
-- p_options_jsonb: JSONB array of objects {optionText, correct}
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
    v_correct_count INT;
    v_options_count INT;
    v_qid BIGINT;
    v_idx INT := 0;
    v_opt JSONB;
    v_label TEXT;
BEGIN
    IF p_question_text IS NULL OR btrim(p_question_text) = '' THEN
        RAISE EXCEPTION 'LTQ20: Question text cannot be blank.' USING ERRCODE = 'LTQ20';
    END IF;

    SELECT course_id INTO v_course_id FROM public.quizzes WHERE id = p_assessment_id AND quiz_type = 'FINAL';
    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Assessment % does not exist or is not FINAL.', p_assessment_id USING ERRCODE = 'LTQ03';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_user_id);

    v_options_count := COALESCE(JSONB_ARRAY_LENGTH(p_options_jsonb), 0);
    IF v_options_count < 2 THEN
        RAISE EXCEPTION 'LTQ21: A question must have at least two options.' USING ERRCODE = 'LTQ21';
    END IF;

    SELECT COUNT(*) INTO v_correct_count FROM JSONB_ARRAY_ELEMENTS(p_options_jsonb) elem WHERE (elem->>'correct')::BOOLEAN IS TRUE;
    -- Note: above expression may fail if 'correct' missing; more robust:
    SELECT SUM(CASE WHEN (opt->>'correct')::BOOLEAN IS TRUE THEN 1 ELSE 0 END) INTO v_correct_count
    FROM JSONB_ARRAY_ELEMENTS(p_options_jsonb) AS opt;

    IF v_correct_count <> 1 THEN
        RAISE EXCEPTION 'LTQ22: Exactly one option must be marked correct.' USING ERRCODE = 'LTQ22';
    END IF;

    -- Insert question
    INSERT INTO public.quiz_questions (quiz_id, question_text, sequence_order)
    VALUES (p_assessment_id, p_question_text, 0)
    RETURNING id INTO v_qid;

    -- Insert options with labels A, B, C...
    FOR v_idx IN 0..(v_options_count - 1) LOOP
        v_opt := p_options_jsonb->v_idx;
        v_label := chr(ascii('A') + v_idx);
        IF v_opt->>'optionText' IS NULL OR btrim(v_opt->>'optionText') = '' THEN
            RAISE EXCEPTION 'LTQ23: Option text cannot be blank.' USING ERRCODE = 'LTQ23';
        END IF;
        INSERT INTO public.quiz_options (question_id, option_label, option_text, is_correct)
        VALUES (v_qid, v_label, v_opt->>'optionText', (v_opt->>'correct')::BOOLEAN);
    END LOOP;

    RETURN v_qid;
END;
$$;

-- 5. sp_final_assessment_question_update(p_actor_user_id, p_question_id, p_question_text, p_options_jsonb)
CREATE OR REPLACE FUNCTION public.sp_final_assessment_question_update(
    p_actor_user_id BIGINT,
    p_question_id BIGINT,
    p_question_text TEXT,
    p_options_jsonb JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz_id BIGINT;
    v_course_id BIGINT;
    v_correct_count INT;
    v_options_count INT;
    v_idx INT := 0;
    v_opt JSONB;
    v_label TEXT;
BEGIN
    SELECT quiz_id INTO v_quiz_id FROM public.quiz_questions WHERE id = p_question_id;
    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ24: Question % does not exist.', p_question_id USING ERRCODE = 'LTQ24';
    END IF;

    SELECT course_id INTO v_course_id FROM public.quizzes WHERE id = v_quiz_id AND quiz_type = 'FINAL';
    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Assessment does not exist or is not FINAL.' USING ERRCODE = 'LTQ03';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_user_id);

    IF p_question_text IS NULL OR btrim(p_question_text) = '' THEN
        RAISE EXCEPTION 'LTQ20: Question text cannot be blank.' USING ERRCODE = 'LTQ20';
    END IF;

    v_options_count := COALESCE(JSONB_ARRAY_LENGTH(p_options_jsonb), 0);
    IF v_options_count < 2 THEN
        RAISE EXCEPTION 'LTQ21: A question must have at least two options.' USING ERRCODE = 'LTQ21';
    END IF;

    SELECT SUM(CASE WHEN (opt->>'correct')::BOOLEAN IS TRUE THEN 1 ELSE 0 END) INTO v_correct_count
    FROM JSONB_ARRAY_ELEMENTS(p_options_jsonb) AS opt;

    IF v_correct_count <> 1 THEN
        RAISE EXCEPTION 'LTQ22: Exactly one option must be marked correct.' USING ERRCODE = 'LTQ22';
    END IF;

    -- Update question text
    UPDATE public.quiz_questions SET question_text = p_question_text, updated_at = CURRENT_TIMESTAMP WHERE id = p_question_id;

    -- Delete existing options and recreate
    DELETE FROM public.quiz_options WHERE question_id = p_question_id;

    FOR v_idx IN 0..(v_options_count - 1) LOOP
        v_opt := p_options_jsonb->v_idx;
        v_label := chr(ascii('A') + v_idx);
        IF v_opt->>'optionText' IS NULL OR btrim(v_opt->>'optionText') = '' THEN
            RAISE EXCEPTION 'LTQ23: Option text cannot be blank.' USING ERRCODE = 'LTQ23';
        END IF;
        INSERT INTO public.quiz_options (question_id, option_label, option_text, is_correct)
        VALUES (p_question_id, v_label, v_opt->>'optionText', (v_opt->>'correct')::BOOLEAN);
    END LOOP;
END;
$$;

-- 6. sp_final_assessment_question_delete(p_actor_user_id, p_question_id)
CREATE OR REPLACE FUNCTION public.sp_final_assessment_question_delete(
    p_actor_user_id BIGINT,
    p_question_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz_id BIGINT;
    v_course_id BIGINT;
BEGIN
    SELECT quiz_id INTO v_quiz_id FROM public.quiz_questions WHERE id = p_question_id;
    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ24: Question % does not exist.', p_question_id USING ERRCODE = 'LTQ24';
    END IF;
    SELECT course_id INTO v_course_id FROM public.quizzes WHERE id = v_quiz_id AND quiz_type = 'FINAL';
    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Assessment does not exist or is not FINAL.' USING ERRCODE = 'LTQ03';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_user_id);

    DELETE FROM public.quiz_options WHERE question_id = p_question_id;
    DELETE FROM public.quiz_questions WHERE id = p_question_id;
END;
$$;

-- 7. fn_final_assessment_validate(p_assessment_id)
CREATE OR REPLACE FUNCTION public.fn_final_assessment_validate(
    p_assessment_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz_exists BOOLEAN;
    v_valid_questions INT;
BEGIN
    SELECT EXISTS(SELECT 1 FROM public.quizzes WHERE id = p_assessment_id AND quiz_type = 'FINAL') INTO v_quiz_exists;
    IF NOT v_quiz_exists THEN
        RAISE EXCEPTION 'LTQ03: Assessment % does not exist or is not FINAL.', p_assessment_id USING ERRCODE = 'LTQ03';
    END IF;

    SELECT COUNT(*) INTO v_valid_questions
    FROM public.quiz_questions qq
    WHERE qq.quiz_id = p_assessment_id
      AND (SELECT COUNT(*) FROM public.quiz_options qo WHERE qo.question_id = qq.id) >= 2
      AND (SELECT COUNT(*) FILTER (WHERE qo2.is_correct) FROM public.quiz_options qo2 WHERE qo2.question_id = qq.id) = 1;

    IF v_valid_questions < 10 THEN
        RAISE EXCEPTION 'LTQ12: Final assessment % does not contain at least 10 valid questions.', p_assessment_id USING ERRCODE = 'LTQ12';
    END IF;

    RETURN TRUE;
END;
$$;

-- 8. fn_final_assessment_status(p_student_user_id, p_course_id)
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

    SELECT id, progress_pct, status, final_score_pct INTO v_enrollment_id, v_progress, v_status, v_already_passed
    FROM public.enrollments WHERE user_id = p_student_user_id AND course_id = p_course_id LIMIT 1;

    IF v_enrollment_id IS NULL THEN
        enrolled := FALSE;
        RETURN NEXT;
        RETURN;
    END IF;
    enrolled := TRUE;
    content_complete := COALESCE(v_progress, 0) >= 100.0;
    already_passed := v_already_passed IS NOT NULL;

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

    SELECT COUNT(*) INTO v_qcount FROM public.quiz_questions qq WHERE qq.quiz_id = v_quiz_id;
    question_count := v_qcount;

    SELECT COUNT(*) INTO v_attempts_today FROM public.quiz_attempts WHERE enrollment_id = v_enrollment_id AND quiz_id = v_quiz_id AND attempt_date = CURRENT_DATE;
    attempts_today := v_attempts_today;
    remaining_attempts := GREATEST(0, COALESCE(v_daily_limit, 0) - v_attempts_today);

    eligible := content_complete AND NOT already_passed AND v_qcount >= v_qper AND remaining_attempts > 0 AND v_status = 'active';

    RETURN NEXT;
    RETURN;
END;
$$;

-- 9. sp_final_assessment_start_attempt(p_student_user_id, p_course_id)
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
    v_row RECORD;
    v_snapshot JSONB;
BEGIN
    -- Resolve enrollment
    SELECT id INTO v_enrollment_id FROM public.enrollments WHERE user_id = p_student_user_id AND course_id = p_course_id LIMIT 1;
    IF v_enrollment_id IS NULL THEN
        RAISE EXCEPTION 'LTQ01: Enrollment does not exist for student % and course %.', p_student_user_id, p_course_id USING ERRCODE = 'LTQ01';
    END IF;

    -- Resolve active final quiz
    SELECT id INTO v_quiz_id FROM public.quizzes WHERE course_id = p_course_id AND quiz_type = 'FINAL' AND is_active = TRUE LIMIT 1;
    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ03: Final assessment not found for course %.', p_course_id USING ERRCODE = 'LTQ03';
    END IF;

    -- Delegate to lower-level start which validates limits and snapshots ordering
    SELECT * INTO v_row FROM public.sp_start_quiz_attempt(v_enrollment_id, v_quiz_id);
    attempt_id := v_row.attempt_id;

    -- Build snapshot JSON for the student (no is_correct)
    SELECT jsonb_build_object(
        'attemptId', attempt_id,
        'quizId', v_quiz_id,
        'enrollmentId', v_enrollment_id,
        'startedAt', (SELECT started_at::timestamptz FROM public.quiz_attempts WHERE id = attempt_id),
        'questions', COALESCE(
            (SELECT jsonb_agg(qobj ORDER BY qobj->>'displayOrder') FROM (
                SELECT jsonb_build_object(
                    'questionId', qaq.question_id,
                    'displayOrder', qaq.display_order,
                    'questionText', qq.question_text,
                    'options', (
                        SELECT jsonb_agg(jsonb_build_object('optionId', qao.option_id, 'displayLabel', chr(ascii('A') + qao.display_order - 1), 'optionText', qo.option_text) ORDER BY qao.display_order)
                        FROM public.quiz_attempt_option_order qao
                        JOIN public.quiz_options qo ON qo.id = qao.option_id
                        WHERE qao.attempt_id = attempt_id AND qao.question_id = qaq.question_id
                    )
                ) AS qobj
                FROM public.quiz_attempt_questions qaq
                JOIN public.quiz_questions qq ON qq.id = qaq.question_id
                WHERE qaq.attempt_id = attempt_id
            ) sub), '[]'::jsonb)
    ) INTO v_snapshot;

    snapshot := v_snapshot;
    RETURN NEXT;
    RETURN;
END;
$$;

-- 10. fn_final_assessment_attempt_get(p_student_user_id, p_attempt_id)
CREATE OR REPLACE FUNCTION public.fn_final_assessment_attempt_get(
    p_student_user_id BIGINT,
    p_attempt_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_enrollment_user BIGINT;
    v_attempt_exists BOOLEAN;
    v_snapshot JSONB;
BEGIN
    SELECT e.user_id INTO v_enrollment_user
    FROM public.quiz_attempts qa
    JOIN public.enrollments e ON e.id = qa.enrollment_id
    WHERE qa.id = p_attempt_id;

    IF v_enrollment_user IS NULL OR v_enrollment_user <> p_student_user_id THEN
        RAISE EXCEPTION 'LTQ09: Attempt % does not belong to user %.', p_attempt_id, p_student_user_id USING ERRCODE = 'LTQ09';
    END IF;

    -- Build and return same sanitized snapshot as start
    SELECT jsonb_build_object(
        'attemptId', p_attempt_id,
        'quizId', (SELECT quiz_id FROM public.quiz_attempts WHERE id = p_attempt_id),
        'enrollmentId', (SELECT enrollment_id FROM public.quiz_attempts WHERE id = p_attempt_id),
        'startedAt', (SELECT started_at::timestamptz FROM public.quiz_attempts WHERE id = p_attempt_id),
        'questions', COALESCE(
            (SELECT jsonb_agg(qobj ORDER BY qobj->>'displayOrder') FROM (
                SELECT jsonb_build_object(
                    'questionId', qaq.question_id,
                    'displayOrder', qaq.display_order,
                    'questionText', qq.question_text,
                    'options', (
                        SELECT jsonb_agg(jsonb_build_object('optionId', qao.option_id, 'displayLabel', chr(ascii('A') + qao.display_order - 1), 'optionText', qo.option_text) ORDER BY qao.display_order)
                        FROM public.quiz_attempt_option_order qao
                        JOIN public.quiz_options qo ON qo.id = qao.option_id
                        WHERE qao.attempt_id = p_attempt_id AND qao.question_id = qaq.question_id
                    )
                ) AS qobj
                FROM public.quiz_attempt_questions qaq
                JOIN public.quiz_questions qq ON qq.id = qaq.question_id
                WHERE qaq.attempt_id = p_attempt_id
            ) sub), '[]'::jsonb)
    ) INTO v_snapshot;

    RETURN v_snapshot;
END;
$$;

-- 11. sp_final_assessment_save_answer(p_student_user_id, p_attempt_id, p_question_id, p_selected_option_id)
CREATE OR REPLACE FUNCTION public.sp_final_assessment_save_answer(
    p_student_user_id BIGINT,
    p_attempt_id BIGINT,
    p_question_id BIGINT,
    p_selected_option_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner BIGINT;
    v_status VARCHAR(20);
    v_belongs BOOLEAN;
    v_option_in_snapshot BOOLEAN;
BEGIN
    SELECT e.user_id, qa.status INTO v_owner, v_status
    FROM public.quiz_attempts qa
    JOIN public.enrollments e ON e.id = qa.enrollment_id
    WHERE qa.id = p_attempt_id;

    IF v_owner IS NULL OR v_owner <> p_student_user_id THEN
        RAISE EXCEPTION 'LTQ09: Attempt % does not belong to user %.', p_attempt_id, p_student_user_id USING ERRCODE = 'LTQ09';
    END IF;

    IF v_status <> 'in_progress' THEN
        RAISE EXCEPTION 'LTQ13: Attempt % is not in progress.', p_attempt_id USING ERRCODE = 'LTQ13';
    END IF;

    SELECT EXISTS (SELECT 1 FROM public.quiz_attempt_questions WHERE attempt_id = p_attempt_id AND question_id = p_question_id) INTO v_belongs;
    IF NOT v_belongs THEN
        RAISE EXCEPTION 'LTQ11: Question % is not part of attempt %.', p_question_id, p_attempt_id USING ERRCODE = 'LTQ11';
    END IF;

    SELECT EXISTS (SELECT 1 FROM public.quiz_attempt_option_order WHERE attempt_id = p_attempt_id AND question_id = p_question_id AND option_id = p_selected_option_id) INTO v_option_in_snapshot;
    IF NOT v_option_in_snapshot THEN
        RAISE EXCEPTION 'LTQ07: Option % is not valid for question % in attempt %.', p_selected_option_id, p_question_id, p_attempt_id USING ERRCODE = 'LTQ07';
    END IF;

    -- Upsert answer using underlying procedure logic (determine correctness from quiz_options)
    PERFORM public.sp_answer_quiz_question(p_attempt_id, p_question_id, p_selected_option_id, FALSE, p_student_user_id);
END;
$$;

-- 12. sp_final_assessment_submit(p_student_user_id, p_attempt_id)
CREATE OR REPLACE FUNCTION public.sp_final_assessment_submit(
    p_student_user_id BIGINT,
    p_attempt_id BIGINT
)
RETURNS TABLE (attempt_id BIGINT, score_pct NUMERIC(5,2), passing_score NUMERIC(5,2), passed BOOLEAN, course_completed BOOLEAN, submitted_at TIMESTAMPTZ)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner BIGINT;
    v_status VARCHAR(20);
    v_quiz_id BIGINT;
    v_enrollment_id BIGINT;
    v_course_completed BOOLEAN := FALSE;
    v_res RECORD;
    v_pass NUMERIC(5,2);
BEGIN
    SELECT e.user_id, qa.status, qa.quiz_id, qa.enrollment_id INTO v_owner, v_status, v_quiz_id, v_enrollment_id
    FROM public.quiz_attempts qa
    JOIN public.enrollments e ON e.id = qa.enrollment_id
    WHERE qa.id = p_attempt_id;

    IF v_owner IS NULL OR v_owner <> p_student_user_id THEN
        RAISE EXCEPTION 'LTQ09: Attempt % does not belong to user %.', p_attempt_id, p_student_user_id USING ERRCODE = 'LTQ09';
    END IF;

    IF v_status <> 'in_progress' THEN
        RAISE EXCEPTION 'LTQ05: Attempt % was already submitted.', p_attempt_id USING ERRCODE = 'LTQ05';
    END IF;

    -- Validate there are exactly 10 snapshotted questions
    IF (SELECT COUNT(*) FROM public.quiz_attempt_questions WHERE attempt_id = p_attempt_id) <> 10 THEN
        RAISE EXCEPTION 'LTQ14: Attempt % does not contain 10 questions.', p_attempt_id USING ERRCODE = 'LTQ14';
    END IF;

    -- Ensure all 10 have answers
    IF (SELECT COUNT(*) FROM public.quiz_attempt_questions qaq LEFT JOIN public.attempt_answers aa ON aa.attempt_id = qaq.attempt_id AND aa.question_id = qaq.question_id WHERE qaq.attempt_id = p_attempt_id AND aa.selected_option_id IS NULL) > 0 THEN
        RAISE EXCEPTION 'LTQ15: Not all questions have been answered for attempt %.', p_attempt_id USING ERRCODE = 'LTQ15';
    END IF;

    -- Delegate to grading routine that computes score and updates rows
    SELECT * INTO v_res FROM public.sp_submit_quiz_attempt(p_attempt_id, FALSE);

    -- Determine if course now completed
    SELECT status = 'completed' INTO v_course_completed FROM public.enrollments WHERE id = v_enrollment_id;

    attempt_id := v_res.attempt_id;
    score_pct := v_res.score_pct;
    passing_score := (SELECT passing_score FROM public.quizzes WHERE id = v_quiz_id);
    passed := v_res.passed;
    submitted_at := v_res.submitted_at;
    course_completed := v_course_completed;

    RETURN NEXT;
    RETURN;
END;
$$;

-- 13. fn_final_assessment_history(p_student_user_id, p_course_id)
CREATE OR REPLACE FUNCTION public.fn_final_assessment_history(
    p_student_user_id BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (submission_id BIGINT, quiz_id BIGINT, score_pct NUMERIC(5,2), passed BOOLEAN, submitted_at TIMESTAMPTZ)
LANGUAGE sql
AS $$
    SELECT qs.id, qs.quiz_id, qs.score_pct, qs.passed, qs.submitted_at
    FROM public.quiz_submissions qs
    JOIN public.quizzes q ON q.id = qs.quiz_id
    WHERE qs.user_id = p_student_user_id
      AND q.course_id = p_course_id
    ORDER BY qs.submitted_at DESC;
$$;

-- End of V24
