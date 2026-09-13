DROP FUNCTION IF EXISTS public.fn_lesson_quiz_bank(BIGINT, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION public.fn_lesson_quiz_bank(
    p_actor_id BIGINT,
    p_lesson VARCHAR,
    p_course VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    question_id BIGINT,
    question_text TEXT,
    sequence_order INTEGER,
    option_id BIGINT,
    option_label VARCHAR(5),
    option_text TEXT,
    is_correct BOOLEAN
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

    RETURN QUERY
    SELECT
        qq.id,
        qq.question_text,
        qq.sequence_order,
        qo.id,
        qo.option_label,
        qo.option_text,
        qo.is_correct
    FROM public.quiz_questions qq
    JOIN public.quizzes q
        ON q.id = qq.quiz_id
       AND q.quiz_type = 'LESSON'
       AND q.lesson_id = v_lesson_id
    LEFT JOIN public.quiz_options qo
        ON qo.question_id = qq.id
    ORDER BY
        qq.sequence_order ASC,
        qq.id ASC,
        qo.option_label ASC;
END;
$$;