-- =========================================================
-- sp_update_lesson
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_update_lesson(
    p_actor_id               BIGINT,
    p_lesson_id              BIGINT,
    p_title                  VARCHAR,
    p_description            TEXT,
    p_sequence_order         INTEGER,
    p_estimated_duration_minutes INTEGER,
    p_is_preview             BOOLEAN
)
RETURNS TABLE (
    lesson_id                BIGINT,
    module_id                BIGINT,
    course_id                BIGINT,
    title                    VARCHAR,
    description              TEXT,
    sequence_order           INTEGER,
    estimated_duration_minutes INTEGER,
    is_preview               BOOLEAN,
    created_at               TIMESTAMPTZ,
    updated_at               TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_module_id BIGINT;
    v_sequence  INTEGER;
BEGIN
    SELECT l.course_id, l.module_id
    INTO v_course_id, v_module_id
    FROM public.lessons l WHERE l.id = p_lesson_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Lesson % does not exist.', p_lesson_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Lesson title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(lessons.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.lessons
        WHERE lessons.module_id = v_module_id;
    END IF;

    UPDATE public.lessons
    SET title = BTRIM(p_title),
        description = p_description,
        sequence_order = v_sequence,
        estimated_duration_minutes = GREATEST(COALESCE(p_estimated_duration_minutes, 0), 0),
        is_preview = COALESCE(p_is_preview, FALSE)
    WHERE id = p_lesson_id
    RETURNING
        public.lessons.id,
        public.lessons.module_id,
        public.lessons.course_id,
        public.lessons.title,
        public.lessons.description,
        public.lessons.sequence_order,
        public.lessons.estimated_duration_minutes,
        public.lessons.is_preview,
        public.lessons.updated_at,
        public.lessons.updated_at
    INTO lesson_id, module_id, course_id, title, description, sequence_order,
         estimated_duration_minutes, is_preview, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', 'LTC15', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_lesson unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the lesson: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
