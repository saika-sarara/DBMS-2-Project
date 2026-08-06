-- =========================================================
-- fn_find_blocking_course
--
-- FUNCTION for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- First unsatisfied prerequisite course, or an empty set when every
-- prerequisite is satisfied. Used to tell the student what blocks the
-- course.

CREATE OR REPLACE FUNCTION public.fn_find_blocking_course(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    blocking_course_id    BIGINT,
    blocking_course_title TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.title::TEXT
    FROM public.course_prerequisites cp
    JOIN public.courses c ON c.id = cp.prerequisite_course_id
    WHERE cp.course_id = p_course_id
      AND NOT public.fn_prerequisite_satisfied(p_student_id, cp.prerequisite_course_id)
    ORDER BY c.id
    LIMIT 1;

    RETURN;
END;
$$;
