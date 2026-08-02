-- =========================================================
-- trg_update_track_progress
--
-- AFTER INSERT / UPDATE OF progress_pct, status ON enrollments.
-- Recalculates track_enrollments.progress_pct for every track that
-- contains the course. When a track reaches 100% it is marked
-- completed.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_update_track_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE track_enrollments te
    SET progress_pct = cp.new_progress,
        status = CASE
                    WHEN cp.new_progress >= 100 AND te.status = 'active' THEN 'completed'
                    ELSE te.status
                 END,
        completed_at = CASE
                    WHEN cp.new_progress >= 100 AND te.status = 'active'
                         THEN COALESCE(te.completed_at, CURRENT_TIMESTAMP)
                    ELSE te.completed_at
                 END
    FROM (
        SELECT te2.id AS track_enrollment_id,
               fn_calculate_track_progress(NEW.user_id, te2.track_id) AS new_progress
        FROM track_enrollments te2
        WHERE te2.user_id = NEW.user_id
          AND EXISTS (
              SELECT 1
              FROM track_courses tc2
              WHERE tc2.track_id = te2.track_id
                AND tc2.course_id = NEW.course_id
          )
    ) cp
    WHERE te.id = cp.track_enrollment_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_track_progress ON enrollments;
CREATE TRIGGER trg_update_track_progress
AFTER INSERT OR UPDATE OF progress_pct, status ON enrollments
FOR EACH ROW
EXECUTE FUNCTION fn_update_track_progress();
