-- =========================================================
-- fn_prerequisite_engine_course_access
--
-- FUNCTION for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 3. The prerequisite engine contract (REAL body)
-- V6 created this function as a contract placeholder that always
-- answered "allowed". This migration replaces only the BODY (the
-- signature stays identical). Enrollment (sp_enroll_student,
-- fn_student_course_access, card status) and progress (lesson-unlock
-- triggers) already treat this function as their ONLY entry point
-- into prerequisite decisions, so they start enforcing prerequisites
-- automatically.

CREATE OR REPLACE FUNCTION public.fn_prerequisite_engine_course_access(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    allowed            BOOLEAN,
    reason_code        TEXT,
    message            TEXT,
    blocking_course_id BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_blocking_id    BIGINT;
    v_blocking_title TEXT;
BEGIN
    IF public.fn_check_prerequisites_met(p_student_id, p_course_id) THEN
        allowed := TRUE;
        reason_code := 'PREREQUISITES_OK';
        message := NULL;
        blocking_course_id := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT bc.blocking_course_id, bc.blocking_course_title
    INTO v_blocking_id, v_blocking_title
    FROM public.fn_find_blocking_course(p_student_id, p_course_id) bc
    LIMIT 1;

    allowed := FALSE;
    reason_code := 'PREREQUISITES_LOCKED';
    message := 'Course is locked until prerequisite "'
               || COALESCE(v_blocking_title, 'a required course')
               || '" is completed or bypassed.';
    blocking_course_id := v_blocking_id;
    RETURN NEXT;
    RETURN;
END;
$$;
