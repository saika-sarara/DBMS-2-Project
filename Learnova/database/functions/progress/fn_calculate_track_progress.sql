-- =========================================================
-- fn_calculate_track_progress
--
-- FUNCTION for the progress feature.
-- Source of truth: progress.sql (V7). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_calculate_track_progress(
    p_student_id BIGINT,
    p_track_id   BIGINT
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_courses INT;
    v_sum_progress  NUMERIC;
BEGIN
    SELECT COUNT(tc.course_id),
           COALESCE(SUM(e.progress_pct), 0)
    INTO v_total_courses, v_sum_progress
    FROM public.track_courses tc
    LEFT JOIN public.enrollments e
           ON e.course_id = tc.course_id
          AND e.user_id = p_student_id
    WHERE tc.track_id = p_track_id;

    IF v_total_courses = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND(v_sum_progress / v_total_courses, 2);
END;
$$;
