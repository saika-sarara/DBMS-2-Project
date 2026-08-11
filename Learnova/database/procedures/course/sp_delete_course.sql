-- =========================================================
-- sp_delete_course
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_delete_course(
    p_actor_id  BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id BIGINT,
    title     VARCHAR,
    slug      VARCHAR,
    status    VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_title VARCHAR;
    v_slug  VARCHAR;
    v_status VARCHAR;
BEGIN
    SELECT c.title, c.slug, c.status INTO v_title, v_slug, v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(p_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable. Only draft or rejected courses can be deleted.'
            USING ERRCODE = 'LTC12';
    END IF;

    DELETE FROM public.courses WHERE id = p_course_id;

    course_id := p_course_id;
    title     := v_title;
    slug      := v_slug;
    status    := v_status;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11', 'LTC12') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_delete_course unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while deleting the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
