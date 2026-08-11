-- =========================================================
-- sp_remove_course_prerequisite
--
-- PROCEDURE for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_remove_course_prerequisite(
    p_actor_id               BIGINT,
    p_course_id              BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS TABLE (
    course_id              BIGINT,
    prerequisite_course_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    DELETE FROM public.course_prerequisites
    WHERE course_id = p_course_id
      AND prerequisite_course_id = p_prerequisite_course_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'LTP03: Prerequisite relation for course % on course % does not exist.',
            p_prerequisite_course_id, p_course_id
            USING ERRCODE = 'LTP03';
    END IF;

    course_id := p_course_id;
    prerequisite_course_id := p_prerequisite_course_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTP03') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_remove_course_prerequisite unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while removing the prerequisite: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
