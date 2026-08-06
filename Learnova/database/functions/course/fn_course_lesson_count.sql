-- =========================================================
-- fn_course_lesson_count
--
-- FUNCTION for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_course_lesson_count(p_course_id BIGINT)
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT COUNT(*)::BIGINT
    FROM public.lessons
    WHERE course_id = p_course_id;
$$;
