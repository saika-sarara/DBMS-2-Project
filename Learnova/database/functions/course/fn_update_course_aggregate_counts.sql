-- =========================================================
-- fn_update_course_aggregate_counts
--
-- FUNCTION for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Recalculates the denormalized aggregate counters on courses.

CREATE OR REPLACE FUNCTION public.fn_update_course_aggregate_counts(p_course_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.courses
    SET total_lessons = (
            SELECT COUNT(*)::INTEGER
            FROM public.lessons
            WHERE course_id = p_course_id
        ),
        estimated_duration_minutes = (
            SELECT COALESCE(SUM(estimated_duration_minutes), 0)::INTEGER
            FROM public.lessons
            WHERE course_id = p_course_id
        )
    WHERE id = p_course_id;
END;
$$;
