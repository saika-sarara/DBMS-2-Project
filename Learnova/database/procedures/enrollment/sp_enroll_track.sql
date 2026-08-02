-- =========================================================
-- sp_enroll_track
--
-- The database command used to enroll a student in a track.
--
--   1.  User must be an active STUDENT.
--   2.  Track must exist.
--   3.  Track must be published.
--   4.  Duplicate track enrollment is rejected.
--   5.  The track_enrollment row is inserted; the
--       trg_auto_enroll_track trigger then enrolls the student
--       into every published course of the track (source = 'track').
--
-- Implemented as a returning function so Java can read the result.
-- Error codes used by the API layer:
--   LTU01 invalid student   LTT01 track missing / unpublished
--   LTN02 duplicate
-- =========================================================

CREATE OR REPLACE FUNCTION sp_enroll_track(
    p_student_id BIGINT,
    p_track_id   BIGINT
)
RETURNS TABLE (
    track_enrollment_id BIGINT,
    entity_id           BIGINT,
    entity_title        TEXT,
    status              VARCHAR(20),
    progress_pct        NUMERIC(5,2),
    source              VARCHAR(20),
    enrolled_at         TIMESTAMPTZ,
    already_enrolled    BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_track_title  TEXT;
    v_track_status VARCHAR(20);
BEGIN
    IF NOT fn_user_is_active_student(p_student_id) THEN
        RAISE EXCEPTION 'LTU01: Only active students can enroll in tracks.'
            USING ERRCODE = 'LTU01';
    END IF;

    SELECT t.title, t.status
    INTO v_track_title, v_track_status
    FROM tracks t
    WHERE t.id = p_track_id;

    IF v_track_title IS NULL THEN
        RAISE EXCEPTION 'LTT01: Track % does not exist.', p_track_id
            USING ERRCODE = 'LTT01';
    END IF;

    IF v_track_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'LTT01: Track % is not published.', p_track_id
            USING ERRCODE = 'LTT01';
    END IF;

    SELECT te.id, te.status, te.progress_pct, te.enrolled_at
    INTO track_enrollment_id, status, progress_pct, enrolled_at
    FROM track_enrollments te
    WHERE te.user_id = p_student_id
      AND te.track_id = p_track_id;

    IF track_enrollment_id IS NOT NULL THEN
        RAISE EXCEPTION 'LTN02: Student is already enrolled in track %.', p_track_id
            USING ERRCODE = 'LTN02';
    END IF;

    INSERT INTO track_enrollments (user_id, track_id)
    VALUES (p_student_id, p_track_id)
    RETURNING track_enrollments.id,
              track_enrollments.status,
              track_enrollments.progress_pct,
              track_enrollments.enrolled_at
    INTO track_enrollment_id, status, progress_pct, enrolled_at;

    entity_id := p_track_id;
    entity_title := v_track_title;
    source := 'track';
    already_enrolled := FALSE;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        -- Domain errors raised above pass straight through untouched.
        IF SQLSTATE IN ('LTU01', 'LTC01', 'LTT01', 'LTN01', 'LTN02', 'LTC02', 'LTP01') THEN
            RAISE;
        END IF;

        -- Re-raised as one stable code; reported to the server log because
        -- a table insert in this block could not persist (the exception
        -- block's subtransaction is rolled back when the error propagates).
        RAISE LOG 'sp_enroll_track unexpected error sqlstate=%: %', SQLSTATE, SQLERRM;

        RAISE EXCEPTION 'LT500: Unexpected database error while enrolling: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
