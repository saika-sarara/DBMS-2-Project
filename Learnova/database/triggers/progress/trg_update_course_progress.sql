-- =========================================================
-- trg_update_course_progress
--
-- AFTER INSERT / UPDATE OF status / DELETE ON lesson_progress.
-- Recalculates enrollments.progress_pct whenever lesson progress
-- changes. When progress reaches 100% the enrollment is marked
-- completed, which in turn triggers trg_unlock_track_courses_after_completion
-- and trg_update_track_progress.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_update_course_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_enrollment_id BIGINT;
    v_progress      NUMERIC(5,2);
    v_status        VARCHAR(20);
BEGIN
    v_enrollment_id := COALESCE(NEW.enrollment_id, OLD.enrollment_id);

    v_progress := fn_calculate_course_progress(v_enrollment_id);

    SELECT status
    INTO v_status
    FROM enrollments
    WHERE id = v_enrollment_id;

    IF v_status = 'active' AND v_progress >= 100 THEN
        UPDATE enrollments
        SET progress_pct = v_progress,
            status = 'completed',
            completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP)
        WHERE id = v_enrollment_id;
    ELSIF v_status = 'active' OR v_progress < 100 THEN
        UPDATE enrollments
        SET progress_pct = v_progress
        WHERE id = v_enrollment_id
          AND progress_pct <> v_progress;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_update_course_progress ON lesson_progress;
CREATE TRIGGER trg_update_course_progress
AFTER INSERT OR UPDATE OF status OR DELETE ON lesson_progress
FOR EACH ROW
EXECUTE FUNCTION fn_update_course_progress();
