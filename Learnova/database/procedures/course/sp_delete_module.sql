-- =========================================================
-- sp_delete_module
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_delete_module(
    p_actor_id  BIGINT,
    p_module_id BIGINT
)
RETURNS TABLE (module_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
BEGIN
    SELECT course_id INTO v_course_id
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

    DELETE FROM public.modules WHERE id = p_module_id;

    module_id := p_module_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC15') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_delete_module unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while deleting the module: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
