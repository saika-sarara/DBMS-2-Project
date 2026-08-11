-- =========================================================
-- fn_course_is_editable
--
-- FUNCTION for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- A course may only be edited while it is still being authored.

CREATE OR REPLACE FUNCTION public.fn_course_is_editable(p_course_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.courses
        WHERE id = p_course_id
          AND status IN ('DRAFT', 'REJECTED')
    );
$$;
