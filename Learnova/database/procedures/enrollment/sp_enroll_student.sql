-- =========================================================
-- sp_enroll_student
--
-- PROCEDURE for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Enrollment procedures (returning functions)

CREATE OR REPLACE FUNCTION public.sp_enroll_student(
    p_student_id BIGINT,
    p_course_id  BIGINT,
    p_source     TEXT DEFAULT 'standalone'
)
RETURNS TABLE (
    enrollment_id    BIGINT,
    entity_id        BIGINT,
    entity_title     TEXT,
    status           VARCHAR(20),
    progress_pct     NUMERIC(5,2),
    source           VARCHAR(20),
    enrolled_at      TIMESTAMPTZ,
    already_enrolled BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_title       TEXT;
    v_course_status      VARCHAR(20);
    v_normalized_source  VARCHAR(20);
    v_allowed            BOOLEAN;
    v_engine_reason_code TEXT;
    v_engine_message     TEXT;
    v_engine_blocking    BIGINT;
BEGIN
    IF NOT public.fn_user_is_active_student(p_student_id) THEN
        RAISE EXCEPTION 'LTU01: Only active students can enroll in courses.'
            USING ERRCODE = 'LTU01';
    END IF;

    SELECT c.title, c.status
    INTO v_course_title, v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_course_title IS NULL THEN
        RAISE EXCEPTION 'LTC01: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC01';
    END IF;

    IF v_course_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'LTC01: Course % is not published.', p_course_id
            USING ERRCODE = 'LTC01';
    END IF;

    v_normalized_source := LOWER(COALESCE(p_source, 'standalone'));
    IF v_normalized_source NOT IN ('standalone', 'track') THEN
        v_normalized_source := 'standalone';
    END IF;

    SELECT e.id, e.status, e.progress_pct, e.source, e.enrolled_at
    INTO enrollment_id, status, progress_pct, source, enrolled_at
    FROM public.enrollments e
    WHERE e.user_id = p_student_id
      AND e.course_id = p_course_id;

    IF enrollment_id IS NOT NULL THEN
        entity_id := p_course_id;
        entity_title := v_course_title;
        already_enrolled := TRUE;

        IF v_normalized_source = 'standalone' THEN
            IF status = 'active' THEN
                RAISE EXCEPTION 'LTN01: Student is already enrolled in course %.', p_course_id
                    USING ERRCODE = 'LTN01';
            END IF;
            RAISE EXCEPTION 'LTC02: Course % was already completed and cannot be re-enrolled.', p_course_id
                USING ERRCODE = 'LTC02';
        END IF;

        RETURN NEXT;
        RETURN;
    END IF;

    -- Standalone enrollments verify course eligibility through the
    -- prerequisite engine CONTRACT. Enrollment owns no prerequisite
    -- calculation; the engine decides and returns the message.
    IF v_normalized_source = 'standalone' THEN
        SELECT pe.allowed, pe.reason_code, pe.message, pe.blocking_course_id
        INTO v_allowed, v_engine_reason_code, v_engine_message, v_engine_blocking
        FROM public.fn_prerequisite_engine_course_access(p_student_id, p_course_id) pe;

        IF NOT COALESCE(v_allowed, FALSE) THEN
            RAISE EXCEPTION 'LTP01: %',
                COALESCE(NULLIF(v_engine_message, ''), 'Prerequisites for course ' || p_course_id || ' are not satisfied.')
                USING ERRCODE = 'LTP01';
        END IF;
    END IF;

    INSERT INTO public.enrollments (user_id, course_id, source)
    VALUES (p_student_id, p_course_id, v_normalized_source)
    RETURNING public.enrollments.id,
              public.enrollments.status,
              public.enrollments.progress_pct,
              public.enrollments.source,
              public.enrollments.enrolled_at
    INTO enrollment_id, status, progress_pct, source, enrolled_at;

    entity_id := p_course_id;
    entity_title := v_course_title;
    already_enrolled := FALSE;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTU01', 'LTC01', 'LTT01', 'LTN01', 'LTN02', 'LTC02', 'LTP01') THEN
            RAISE;
        END IF;

        -- Reported to the server log (a table insert here could not persist:
        -- the exception block's subtransaction is rolled back when the error
        -- propagates, and there are no autonomous transactions).
        RAISE LOG 'sp_enroll_student unexpected error sqlstate=%: %', SQLSTATE, SQLERRM;

        RAISE EXCEPTION 'LT500: Unexpected database error while enrolling: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
