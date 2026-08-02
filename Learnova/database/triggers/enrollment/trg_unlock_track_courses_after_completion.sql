-- =========================================================
-- trg_unlock_track_courses_after_completion
--
-- AFTER UPDATE OF status ON enrollments.
-- When a course enrollment becomes completed, unlock the first
-- lesson of every other active enrollment of the same student whose
-- prerequisites are now satisfied (e.g. later courses in a track).
-- The prerequisite decision is delegated to the prerequisite engine
-- contract; the trigger does not calculate prerequisites itself.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_unlock_track_courses_after_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE lesson_progress lp
    SET status = 'unlocked',
        unlocked_at = COALESCE(lp.unlocked_at, CURRENT_TIMESTAMP)
    FROM enrollments e
    WHERE lp.enrollment_id = e.id
      AND e.user_id = NEW.user_id
      AND e.status = 'active'
      AND EXISTS (
          SELECT 1
          FROM fn_prerequisite_engine_course_access(NEW.user_id, e.course_id) pe
          WHERE pe.allowed
      )
      AND lp.lesson_id = fn_course_first_lesson_id(e.course_id)
      AND lp.status = 'locked';

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_unlock_track_courses_after_completion ON enrollments;
CREATE TRIGGER trg_unlock_track_courses_after_completion
AFTER UPDATE OF status ON enrollments
FOR EACH ROW
WHEN (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed')
EXECUTE FUNCTION fn_unlock_track_courses_after_completion();
