-- =========================================================
-- fn_student_course_access
--
-- FUNCTION for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- NOTE: fn_prerequisite_satisfied, fn_check_prerequisites_met and
-- fn_find_blocking_course are NOT defined here. They belong to the
-- prerequisite module; enrollment only consumes the engine contract
-- defined in section 3.0.

CREATE OR REPLACE FUNCTION public.fn_student_course_access(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    is_accessible         BOOLEAN,
    reason_code           TEXT,
    reason                TEXT,
    enrollment_status     TEXT,
    progress_pct          NUMERIC(5,2),
    blocking_course_id    BIGINT,
    blocking_course_title TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_title       TEXT;
    v_course_status      VARCHAR(20);
    v_enrollment_status  VARCHAR(20);
    v_progress           NUMERIC(5,2);
    v_allowed            BOOLEAN;
    v_engine_reason_code TEXT;
    v_engine_message     TEXT;
    v_engine_blocking    BIGINT;
BEGIN
    SELECT c.title, c.status
    INTO v_course_title, v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_course_title IS NULL THEN
        is_accessible := FALSE;
        reason_code := 'course_not_found';
        reason := 'Course does not exist.';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_course_status <> 'PUBLISHED' THEN
        is_accessible := FALSE;
        reason_code := 'course_not_published';
        reason := 'Course is not published.';
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT e.status, e.progress_pct
    INTO v_enrollment_status, v_progress
    FROM public.enrollments e
    WHERE e.user_id = p_student_id
      AND e.course_id = p_course_id;

    IF v_enrollment_status IS NULL THEN
        is_accessible := FALSE;
        reason_code := 'not_enrolled';
        reason := 'Student is not enrolled in this course.';
        RETURN NEXT;
        RETURN;
    END IF;

    enrollment_status := v_enrollment_status;
    progress_pct := v_progress;

    IF v_enrollment_status = 'completed' THEN
        is_accessible := TRUE;
        reason_code := 'completed';
        reason := 'Course already completed.';
        RETURN NEXT;
        RETURN;
    END IF;

    -- The prerequisite decision is DELEGATED to the prerequisite
    -- engine contract. Enrollment does not inspect the prerequisite
    -- graph or bypass records itself.
    SELECT pe.allowed, pe.reason_code, pe.message, pe.blocking_course_id
    INTO v_allowed, v_engine_reason_code, v_engine_message, v_engine_blocking
    FROM public.fn_prerequisite_engine_course_access(p_student_id, p_course_id) pe;

    IF COALESCE(v_allowed, FALSE) THEN
        is_accessible := TRUE;
        reason_code := 'active';
        reason := 'Course is accessible.';
        RETURN NEXT;
        RETURN;
    END IF;

    is_accessible := FALSE;
    reason_code := 'prerequisites_locked';
    reason := COALESCE(NULLIF(v_engine_message, ''), 'Course is locked until all prerequisites are satisfied.');
    blocking_course_id := v_engine_blocking;

    -- Resolve the title only for display; the blocking decision came
    -- from the prerequisite engine.
    SELECT title
    INTO blocking_course_title
    FROM public.courses
    WHERE id = v_engine_blocking;

    RETURN NEXT;
    RETURN;
END;
$$;
