-- =========================================================
-- trg_prevent_duplicate_enrollment
--
-- BEFORE INSERT ON enrollments.
-- Safety net for direct SQL inserts (outside sp_enroll_student):
-- rejects a second ACTIVE enrollment for the same student/course
-- with a clear error, complementing the unique constraint and the
-- procedure-level check.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_prevent_duplicate_enrollment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM enrollments
        WHERE user_id = NEW.user_id
          AND course_id = NEW.course_id
          AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Student is already enrolled in course %.', NEW.course_id
            USING ERRCODE = 'LTN01';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_enrollment ON enrollments;
CREATE TRIGGER trg_prevent_duplicate_enrollment
BEFORE INSERT ON enrollments
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_duplicate_enrollment();
