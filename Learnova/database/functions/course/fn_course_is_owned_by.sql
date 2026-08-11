-- =========================================================
-- fn_course_is_owned_by
--
-- FUNCTION for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 6. Helper functions (ownership, editability, aggregates)

CREATE OR REPLACE FUNCTION public.fn_course_is_owned_by(
    p_course_id BIGINT,
    p_user_id   BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_owner_id BIGINT;
BEGIN
    SELECT instructor_id INTO v_owner_id
    FROM public.courses
    WHERE id = p_course_id;

    RETURN v_owner_id IS NOT NULL AND v_owner_id = p_user_id;
END;
$$;
