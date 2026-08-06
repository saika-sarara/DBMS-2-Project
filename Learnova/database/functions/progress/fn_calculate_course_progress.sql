-- =========================================================
-- fn_calculate_course_progress
--
-- FUNCTION for the progress feature.
-- Source of truth: progress.sql (V7). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_calculate_course_progress(p_enrollment_id BIGINT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_lessons     INT;
    v_completed_lessons INT;
BEGIN
    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE lp.status = 'completed')
    INTO v_total_lessons, v_completed_lessons
    FROM public.lesson_progress lp
    WHERE lp.enrollment_id = p_enrollment_id;

    IF v_total_lessons = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND(
        (v_completed_lessons::NUMERIC / v_total_lessons::NUMERIC) * 100,
        2
    );
END;
$$;
