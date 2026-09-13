-- V42: Fix BIGINT ordinality passed to PostgreSQL chr(integer)

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
    v_lesson_id    BIGINT;
    v_course_id    BIGINT;
    v_quiz_id      BIGINT;
    v_opt_count    INTEGER;
    v_label        VARCHAR(1);
    v_index        INTEGER;
    v_question_id  BIGINT;
BEGIN
    SELECT r.lesson_id, r.course_id
    INTO v_lesson_id, v_course_id
    FROM public.fn_resolve_lesson_quiz(
        p_actor_id,
        p_lesson,
        FALSE,
        p_course
    ) r;

    IF v_lesson_id IS NULL THEN
        RAISE EXCEPTION 'LTQ15: No lesson found for %', p_lesson
            USING ERRCODE = 'LTQ15';
    END IF;

    PERFORM public.fn_require_course_manager(
        v_course_id,
        p_actor_id
    );

    -- Ensure a lesson quiz exists.
    SELECT q.id
    INTO v_quiz_id
    FROM public.quizzes q
    WHERE q.lesson_id = v_lesson_id
      AND q.quiz_type = 'LESSON';

    IF v_quiz_id IS NULL THEN
        INSERT INTO public.quizzes (
            lesson_id,
            course_id,
            title,
            passing_score,
            questions_per_attempt,
            daily_attempt_limit
        )
        SELECT
            v_lesson_id,
            v_course_id,
            l.title,
            60.00,
            5,
            3
        FROM public.lessons l
        WHERE l.id = v_lesson_id
        ON CONFLICT (lesson_id) DO NOTHING
        RETURNING id INTO v_quiz_id;
    END IF;

    IF v_quiz_id IS NULL THEN
        SELECT id
        INTO v_quiz_id
        FROM public.quizzes
        WHERE lesson_id = v_lesson_id
          AND quiz_type = 'LESSON';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM public.quiz_questions qq
        WHERE qq.quiz_id = v_quiz_id
    ) >= 20 THEN
        RAISE EXCEPTION
            'LTQ17: The question bank for this lesson is full (max 20).'
            USING ERRCODE = 'LTQ17';
    END IF;

    IF BTRIM(COALESCE(p_text, '')) = '' THEN
        RAISE EXCEPTION 'LTQ18: Question text is required.'
            USING ERRCODE = 'LTQ18';
    END IF;

    IF p_options IS NULL
       OR jsonb_array_length(p_options) < 2
       OR jsonb_array_length(p_options) > 6 THEN
        RAISE EXCEPTION
            'LTQ18: A question needs between 2 and 6 options.'
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
        RAISE EXCEPTION
            'LTQ18: Correct answer must be one of A-%.',
            CHR((ASCII('A') + v_opt_count - 1)::INTEGER)
            USING ERRCODE = 'LTQ18';
    END IF;

    INSERT INTO public.quiz_questions (
        quiz_id,
        question_text,
        sequence_order
    )
    VALUES (
        v_quiz_id,
        BTRIM(p_text),
        (
            SELECT COALESCE(MAX(sequence_order), 0) + 1
            FROM public.quiz_questions qq
            WHERE qq.quiz_id = v_quiz_id
        )
    )
    RETURNING id INTO v_question_id;

    INSERT INTO public.quiz_options (
        question_id,
        option_label,
        option_text,
        is_correct
    )
    SELECT
        v_question_id,
        CHR((64 + ord)::INTEGER),
        BTRIM(opt_text),
        (CHR((64 + ord)::INTEGER) = v_label)
    FROM jsonb_array_elements_text(p_options)
         WITH ORDINALITY AS t(opt_text, ord);

    question_id := v_question_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN (
            'LTQ15',
            'LTQ17',
            'LTQ18',
            'LTC10',
            'LTC11',
            '23505',
            '23503'
        ) THEN
            RAISE;
        END IF;

        RAISE LOG
            'sp_lesson_quiz_question_create unexpected sqlstate=%: %',
            SQLSTATE,
            SQLERRM;

        RAISE EXCEPTION
            'LT500: Unexpected database error while creating the question: %',
            SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_lesson_quiz_question_update(
    p_actor_id     BIGINT,
    p_question_id  BIGINT,
    p_text         VARCHAR,
    p_options      JSONB,
    p_correct      VARCHAR
)
RETURNS TABLE (question_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_quiz_id    BIGINT;
    v_course_id  BIGINT;
    v_opt_count  INTEGER;
    v_label      VARCHAR(1);
    v_index      INTEGER;
BEGIN
    SELECT qq.quiz_id, q.course_id
    INTO v_quiz_id, v_course_id
    FROM public.quiz_questions qq
    JOIN public.quizzes q
      ON q.id = qq.quiz_id
    WHERE qq.id = p_question_id;

    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION
            'LTQ16: Question % does not exist.',
            p_question_id
            USING ERRCODE = 'LTQ16';
    END IF;

    PERFORM public.fn_require_course_manager(
        v_course_id,
        p_actor_id
    );

    IF BTRIM(COALESCE(p_text, '')) = '' THEN
        RAISE EXCEPTION 'LTQ18: Question text is required.'
            USING ERRCODE = 'LTQ18';
    END IF;

    IF p_options IS NULL
       OR jsonb_array_length(p_options) < 2
       OR jsonb_array_length(p_options) > 6 THEN
        RAISE EXCEPTION
            'LTQ18: A question needs between 2 and 6 options.'
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
        RAISE EXCEPTION
            'LTQ18: Correct answer must be one of A-%.',
            CHR((ASCII('A') + v_opt_count - 1)::INTEGER)
            USING ERRCODE = 'LTQ18';
    END IF;

    UPDATE public.quiz_questions
    SET question_text = BTRIM(p_text)
    WHERE id = p_question_id;

    DELETE FROM public.quiz_options
    WHERE question_id = p_question_id;

    INSERT INTO public.quiz_options (
        question_id,
        option_label,
        option_text,
        is_correct
    )
    SELECT
        p_question_id,
        CHR((64 + ord)::INTEGER),
        BTRIM(opt_text),
        (CHR((64 + ord)::INTEGER) = v_label)
    FROM jsonb_array_elements_text(p_options)
         WITH ORDINALITY AS t(opt_text, ord);

    question_id := p_question_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN (
            'LTQ16',
            'LTQ18',
            'LTC10',
            'LTC11',
            '23503'
        ) THEN
            RAISE;
        END IF;

        RAISE LOG
            'sp_lesson_quiz_question_update unexpected sqlstate=%: %',
            SQLSTATE,
            SQLERRM;

        RAISE EXCEPTION
            'LT500: Unexpected database error while updating the question: %',
            SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;