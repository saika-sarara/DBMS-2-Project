-- =========================================================
-- sp_update_module
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_update_module(
    p_actor_id      BIGINT,
    p_module_id     BIGINT,
    p_title         VARCHAR,
    p_description   TEXT,
    p_sequence_order INTEGER
)
RETURNS TABLE (
    module_id      BIGINT,
    course_id      BIGINT,
    title          VARCHAR,
    description    TEXT,
    sequence_order INTEGER,
    created_at     TIMESTAMPTZ,
    updated_at     TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
    v_sequence  INTEGER;
BEGIN
    SELECT modules.course_id INTO v_course_id
    FROM public.modules WHERE id = p_module_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC15: Module % does not exist.', p_module_id
            USING ERRCODE = 'LTC15';
    END IF;

    PERFORM public.fn_require_course_manager(v_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(v_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Module title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_sequence := COALESCE(p_sequence_order, 0);

    IF v_sequence < 1 THEN
        SELECT COALESCE(MAX(modules.sequence_order), 0) + 1
        INTO v_sequence
        FROM public.modules
        WHERE modules.course_id = v_course_id;
    END IF;

    UPDATE public.modules
    SET title = BTRIM(p_title),
        description = p_description,
        sequence_order = v_sequence
    WHERE id = p_module_id
    RETURNING
        public.modules.id,
        public.modules.course_id,
        public.modules.title,
        public.modules.description,
        public.modules.sequence_order,
        public.modules.created_at,
        public.modules.updated_at
    INTO module_id, course_id, title, description, sequence_order, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', 'LTC15', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_module unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the module: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
