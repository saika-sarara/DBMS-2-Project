-- =========================================================
-- trg_auto_enroll_track
--
-- AFTER INSERT ON track_enrollments.
-- When a student joins a track, enroll them into every published
-- course of the track with source = 'track'. sp_enroll_student is
-- idempotent for track enrollments, so courses the student already
-- has (active or completed) are skipped instead of raising.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_auto_enroll_track()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM sp_enroll_student(NEW.user_id, tc.course_id, 'track')
    FROM track_courses tc
    JOIN courses c ON c.id = tc.course_id
    WHERE tc.track_id = NEW.track_id
      AND c.status = 'PUBLISHED';

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_enroll_track ON track_enrollments;
CREATE TRIGGER trg_auto_enroll_track
AFTER INSERT ON track_enrollments
FOR EACH ROW
EXECUTE FUNCTION fn_auto_enroll_track();
