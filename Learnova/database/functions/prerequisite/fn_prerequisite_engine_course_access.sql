-- =========================================================
-- fn_prerequisite_engine_course_access  (PREREQUISITE MODULE)
--
-- TEMPORARY PLACEHOLDER — not real prerequisite logic.
--
-- This is the CONTRACT the enrollment module depends on. Enrollment
-- (sp_enroll_student, fn_student_course_access and the lesson-unlock
-- triggers) treats this function as its ONLY entry point into
-- prerequisite decisions. It never inspects course_prerequisites or
-- course_bypasses itself.
--
-- Return shape (Option B):
--   allowed            TRUE when prerequisites are satisfied
--   reason_code        machine-readable reason when blocked
--   message            human-readable reason when blocked
--   blocking_course_id the first unsatisfied prerequisite, if any
--
-- The prerequisite module must replace only the BODY (never the
-- signature) when the real engine is implemented.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_prerequisite_engine_course_access(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    allowed            BOOLEAN,
    reason_code        TEXT,
    message            TEXT,
    blocking_course_id BIGINT
)
LANGUAGE sql
AS $$
    SELECT
        TRUE                                AS allowed,
        'PREREQ_ENGINE_PENDING'::TEXT       AS reason_code,
        'Prerequisite engine module is not connected yet.'::TEXT AS message,
        NULL::BIGINT                        AS blocking_course_id;
$$;
