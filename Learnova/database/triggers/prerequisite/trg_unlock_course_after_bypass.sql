-- =========================================================
-- trg_unlock_course_after_bypass  (PREREQUISITE MODULE)
--
-- AFTER INSERT ON course_bypasses.
-- When a student passes a bypass quiz for a prerequisite course,
-- unlock the first lesson of every active enrollment whose
-- prerequisites are now satisfied.
--
-- OWNERSHIP: this trigger reacts to the course_bypasses table and is
-- therefore owned by the prerequisite module, not by enrollment. The
-- prerequisite decision is delegated to the prerequisite engine
-- contract fn_prerequisite_engine_course_access.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_unlock_course_after_bypass()
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

DROP TRIGGER IF EXISTS trg_unlock_course_after_bypass ON course_bypasses;
CREATE TRIGGER trg_unlock_course_after_bypass
AFTER INSERT ON course_bypasses
FOR EACH ROW
EXECUTE FUNCTION fn_unlock_course_after_bypass();
