-- =========================================================
-- fn_calculate_course_progress
--
-- Course progress is derived from lesson_progress:
--   progress = completed lessons / total lessons * 100
-- The value is stored in enrollments.progress_pct by the
-- trg_update_course_progress trigger whenever lesson progress
-- changes. A course with no lessons has 0% progress.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_calculate_course_progress(p_enrollment_id BIGINT)
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
    FROM lesson_progress lp
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
