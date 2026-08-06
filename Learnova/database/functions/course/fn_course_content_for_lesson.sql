-- =========================================================
-- fn_course_content_for_lesson
--
-- FUNCTION for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 9. Lesson content (preview or enrolled-only)

CREATE OR REPLACE FUNCTION public.fn_course_content_for_lesson(
    p_student_id BIGINT,
    p_lesson_id  BIGINT
)
RETURNS TABLE (
    block_id      BIGINT,
    lesson_id     BIGINT,
    block_type    VARCHAR,
    title         VARCHAR,
    body_markdown TEXT,
    resource_url  TEXT,
    sequence_order INTEGER
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_course_id  BIGINT;
    v_is_preview BOOLEAN;
    v_accessible BOOLEAN;
BEGIN
    SELECT l.course_id, l.is_preview
    INTO v_course_id, v_is_preview
    FROM public.lessons l
    WHERE l.id = p_lesson_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC11: Lesson % does not exist.', p_lesson_id
            USING ERRCODE = 'LTC11';
    END IF;

    -- Preview lessons are available to everyone.
    IF v_is_preview THEN
        RETURN QUERY
        SELECT
            cb.id,
            cb.lesson_id,
            cb.block_type,
            cb.title,
            cb.body_markdown,
            cb.resource_url,
            cb.sequence_order
        FROM public.lesson_content_blocks cb
        WHERE cb.lesson_id = p_lesson_id
        ORDER BY cb.sequence_order ASC, cb.id ASC;
        RETURN;
    END IF;

    IF p_student_id IS NULL THEN
        RAISE EXCEPTION 'LTC12: Log in to view this lesson content.'
            USING ERRCODE = 'LTC12';
    END IF;

    SELECT COALESCE(ac.is_accessible, FALSE)
    INTO v_accessible
    FROM public.fn_student_course_access(p_student_id, v_course_id) ac;

    IF NOT v_accessible THEN
        RAISE EXCEPTION 'LTC12: You do not have access to this lesson. Enroll in the course first.'
            USING ERRCODE = 'LTC12';
    END IF;

    RETURN QUERY
    SELECT
        cb.id,
        cb.lesson_id,
        cb.block_type,
        cb.title,
        cb.body_markdown,
        cb.resource_url,
        cb.sequence_order
    FROM public.lesson_content_blocks cb
    WHERE cb.lesson_id = p_lesson_id
    ORDER BY cb.sequence_order ASC, cb.id ASC;
END;
$$;
