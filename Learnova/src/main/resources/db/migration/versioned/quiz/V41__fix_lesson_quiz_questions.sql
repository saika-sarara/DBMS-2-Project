DROP FUNCTION IF EXISTS public.fn_lesson_quiz_questions(
    BIGINT,
    VARCHAR,
    BOOLEAN,
    INTEGER,
    VARCHAR
);

CREATE OR REPLACE FUNCTION public.fn_lesson_quiz_questions(
    p_actor_id BIGINT,
    p_lesson VARCHAR,
    p_bypass BOOLEAN,
    p_count INTEGER,
    p_course VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    question_id BIGINT,
    question_text TEXT,
    option_id BIGINT,
    option_label VARCHAR(5),
    option_text TEXT
)
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
    v_quiz_id BIGINT;
BEGIN
    SELECT r.quiz_id
    INTO v_quiz_id
    FROM public.fn_resolve_lesson_quiz(
        p_actor_id,
        p_lesson,
        p_bypass,
        p_course
    ) r;

    IF v_quiz_id IS NULL THEN
        RAISE EXCEPTION 'LTQ15: Lesson % has no active lesson quiz yet.', p_lesson
            USING ERRCODE = 'LTQ15';
    END IF;

    RETURN QUERY
    WITH picked AS (
        SELECT pick.question_id,
               ROW_NUMBER() OVER (ORDER BY RANDOM()) AS question_order
        FROM public.fn_quiz_pick_questions(v_quiz_id, p_count) AS pick
    )
    SELECT
        picked.question_id,
        qq.question_text,
        qo.id,
        qo.option_label,
        qo.option_text
    FROM picked
    JOIN public.quiz_questions qq
        ON qq.id = picked.question_id
    JOIN public.quiz_options qo
        ON qo.question_id = qq.id
    ORDER BY picked.question_order, RANDOM();

END;
$$;