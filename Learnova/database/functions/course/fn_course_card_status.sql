-- =========================================================
-- fn_course_card_status
--
-- FUNCTION for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Card status (personalized, anonymous-safe)

CREATE OR REPLACE FUNCTION public.fn_course_card_status(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    card_status TEXT,
    is_locked   BOOLEAN,
    is_enrolled BOOLEAN,
    is_completed BOOLEAN,
    lock_reason TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_status        VARCHAR(20);
    v_enr_status    VARCHAR(20);
    v_progress      NUMERIC(5,2);
    v_allowed       BOOLEAN;
    v_engine_reason TEXT;
BEGIN
    IF p_student_id IS NULL THEN
        card_status := 'login_required';
        is_locked := TRUE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := 'Log in to enroll in this course.';
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT c.status INTO v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        card_status := 'unavailable';
        is_locked := TRUE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := 'Course does not exist.';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_status <> 'PUBLISHED' THEN
        card_status := 'unavailable';
        is_locked := TRUE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := 'Course is not published.';
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT e.status, e.progress_pct
    INTO v_enr_status, v_progress
    FROM public.enrollments e
    WHERE e.user_id = p_student_id
      AND e.course_id = p_course_id;

    IF v_enr_status = 'completed' THEN
        card_status := 'completed';
        is_locked := FALSE;
        is_enrolled := TRUE;
        is_completed := TRUE;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_enr_status = 'active' THEN
        is_enrolled := TRUE;
        IF v_progress >= 100 THEN
            card_status := 'completed';
            is_completed := TRUE;
        ELSIF v_progress > 0 THEN
            card_status := 'continue';
        ELSE
            card_status := 'enrolled';
        END IF;
        is_locked := FALSE;
        RETURN NEXT;
        RETURN;
    END IF;

    -- Not enrolled: delegate the lock decision to the prerequisite engine
    -- CONTRACT. The course module never inspects the prerequisite graph.
    SELECT pe.allowed, pe.message
    INTO v_allowed, v_engine_reason
    FROM public.fn_prerequisite_engine_course_access(p_student_id, p_course_id) pe;

    IF COALESCE(v_allowed, FALSE) THEN
        card_status := 'available';
        is_locked := FALSE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := NULL;
    ELSE
        card_status := 'locked';
        is_locked := TRUE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := COALESCE(
            NULLIF(v_engine_reason, ''),
            'This course is locked until all prerequisites are satisfied.'
        );
    END IF;

    RETURN NEXT;
    RETURN;
END;
$$;
