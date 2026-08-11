-- =========================================================
-- sp_create_module
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 9. Module procedures

CREATE OR REPLACE FUNCTION public.sp_create_module(
    p_actor_id     BIGINT,
    p_course_id    BIGINT,
    p_title        VARCHAR,
    p_description  TEXT,
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
    v_sequence INTEGER;
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(p_course_id) THEN
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
        WHERE modules.course_id = p_course_id;
    END IF;

    INSERT INTO public.modules (course_id, title, description, sequence_order)
    VALUES (p_course_id, BTRIM(p_title), p_description, v_sequence)
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
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_create_module unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while creating the module: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
