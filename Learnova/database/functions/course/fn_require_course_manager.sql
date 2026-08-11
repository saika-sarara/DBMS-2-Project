-- =========================================================
-- fn_require_course_manager
--
-- FUNCTION for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Raise a stable LTxxx error unless the caller is allowed.

CREATE OR REPLACE FUNCTION public.fn_require_course_manager(
    p_course_id BIGINT,
    p_actor_id  BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_actor_id IS NULL OR NOT public.fn_user_is_instructor_or_admin(p_actor_id) THEN
        RAISE EXCEPTION 'LTC10: You do not have permission to manage courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    IF NOT public.fn_course_is_owned_by(p_course_id, p_actor_id)
       AND NOT public.fn_user_has_role(p_actor_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: You can only manage your own courses.'
            USING ERRCODE = 'LTC10';
    END IF;
END;
$$;
