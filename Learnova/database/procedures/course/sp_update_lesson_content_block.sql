-- =========================================================
-- sp_update_lesson_content_block
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_update_lesson_content_block(
    p_actor_id      BIGINT,
    p_block_id      BIGINT,
    p_title         VARCHAR,
    p_body_markdown TEXT,
    p_resource_url  TEXT,
    p_sequence_order INTEGER
)
RETURNS TABLE (
    block_id      BIGINT,
    lesson_id     BIGINT,
    block_type    VARCHAR,
    title         VARCHAR,
    body_markdown TEXT,
    resource_url  TEXT,
    sequence_order INTEGER,
    created_at    TIMESTAMPTZ,
    updated_at    TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_lesson_id BIGINT;
    v_sequence  INTEGER;
BEGIN
    SELECT l.course_id, cb.lesson_id, cb.block_type
    INTO v_course_id, v_lesson_id, block_type
    FROM public.lesson_content_blocks cb
    JOIN public.lessons l ON l.id = cb.lesson_id
    WHERE cb.id = p_block_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Content block % does not exist.', p_block_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(lesson_content_blocks.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.lesson_content_blocks
        WHERE lesson_content_blocks.lesson_id = v_lesson_id;
    END IF;

    UPDATE public.lesson_content_blocks
    SET title = p_title,
        body_markdown = p_body_markdown,
        resource_url = p_resource_url,
        sequence_order = v_sequence
    WHERE id = p_block_id
    RETURNING
        public.lesson_content_blocks.id,
        public.lesson_content_blocks.lesson_id,
        public.lesson_content_blocks.block_type,
        public.lesson_content_blocks.title,
        public.lesson_content_blocks.body_markdown,
        public.lesson_content_blocks.resource_url,
        public.lesson_content_blocks.sequence_order,
        public.lesson_content_blocks.created_at,
        public.lesson_content_blocks.updated_at
    INTO block_id, lesson_id, block_type, title, body_markdown, resource_url,
         sequence_order, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC15', 'LTC20', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_lesson_content_block unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the content block: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
