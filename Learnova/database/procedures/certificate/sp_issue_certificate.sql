-- =========================================================
-- sp_issue_certificate
--
-- PROCEDURE for the certificate feature.
-- Source of truth: certificate.sql (V12). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 2. Issue procedure (idempotent)
-- Issues a certificate for a completed course or track. Idempotent:
-- when a certificate already exists it is returned unchanged instead
-- of raising, which makes the auto-issue trigger (below) safe to fire
-- on every completion transition.

CREATE OR REPLACE FUNCTION public.sp_issue_certificate(
    p_student_id BIGINT,
    p_entity_type VARCHAR,
    p_entity_id   BIGINT
)
RETURNS TABLE (
    certificate_id BIGINT,
    user_id        BIGINT,
    type           VARCHAR,
    course_id      BIGINT,
    track_id       BIGINT,
    cert_code      VARCHAR,
    issued_at      TIMESTAMPTZ,
    already_issued BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_normalized_type VARCHAR(20);
    v_completed       BOOLEAN;
    v_code            VARCHAR(100);
BEGIN
    IF NOT public.fn_user_is_active_student(p_student_id) THEN
        RAISE EXCEPTION 'LTU01: Only active students can receive certificates.'
            USING ERRCODE = 'LTU01';
    END IF;

    v_normalized_type := LOWER(BTRIM(COALESCE(p_entity_type, '')));
    IF v_normalized_type NOT IN ('course', 'track') THEN
        RAISE EXCEPTION 'LTCE1: entity_type must be course or track.'
            USING ERRCODE = 'LTCE1';
    END IF;

    -- Existing certificate: return it unchanged (idempotent).
    IF v_normalized_type = 'course' THEN
        SELECT c.id, c.user_id, c.type, c.course_id, c.track_id, c.cert_code, c.issued_at
        INTO certificate_id, user_id, type, course_id, track_id, cert_code, issued_at
        FROM public.certificates c
        WHERE c.user_id = p_student_id
          AND c.type = 'course'
          AND c.course_id = p_entity_id;

        IF certificate_id IS NOT NULL THEN
            already_issued := TRUE;
            RETURN NEXT;
            RETURN;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM public.enrollments
            WHERE user_id = p_student_id
              AND course_id = p_entity_id
              AND status = 'completed'
        )
        INTO v_completed;

        IF NOT v_completed THEN
            RAISE EXCEPTION 'LTCE2: Course % is not completed by the student.', p_entity_id
                USING ERRCODE = 'LTCE2';
        END IF;
    ELSE
        SELECT c.id, c.user_id, c.type, c.course_id, c.track_id, c.cert_code, c.issued_at
        INTO certificate_id, user_id, type, course_id, track_id, cert_code, issued_at
        FROM public.certificates c
        WHERE c.user_id = p_student_id
          AND c.type = 'track'
          AND c.track_id = p_entity_id;

        IF certificate_id IS NOT NULL THEN
            already_issued := TRUE;
            RETURN NEXT;
            RETURN;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM public.track_enrollments
            WHERE user_id = p_student_id
              AND track_id = p_entity_id
              AND status = 'completed'
        )
        INTO v_completed;

        IF NOT v_completed THEN
            RAISE EXCEPTION 'LTCE2: Track % is not completed by the student.', p_entity_id
                USING ERRCODE = 'LTCE2';
        END IF;
    END IF;

    v_code := 'LT-'
              || UPPER(
                  SUBSTRING(
                      MD5(
                          p_student_id::TEXT
                          || ':' || p_entity_type::TEXT
                          || ':' || p_entity_id::TEXT
                          || ':' || CURRENT_TIMESTAMP::TEXT
                      )
                      FOR 14
                  )
              );

    IF v_normalized_type = 'course' THEN
        INSERT INTO public.certificates (user_id, type, course_id, cert_code)
        VALUES (p_student_id, 'course', p_entity_id, v_code)
        RETURNING
            public.certificates.id,
            public.certificates.user_id,
            public.certificates.type,
            public.certificates.course_id,
            public.certificates.track_id,
            public.certificates.cert_code,
            public.certificates.issued_at
        INTO certificate_id, user_id, type, course_id, track_id, cert_code, issued_at;
    ELSE
        INSERT INTO public.certificates (user_id, type, track_id, cert_code)
        VALUES (p_student_id, 'track', p_entity_id, v_code)
        RETURNING
            public.certificates.id,
            public.certificates.user_id,
            public.certificates.type,
            public.certificates.course_id,
            public.certificates.track_id,
            public.certificates.cert_code,
            public.certificates.issued_at
        INTO certificate_id, user_id, type, course_id, track_id, cert_code, issued_at;
    END IF;

    already_issued := FALSE;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTU01', 'LTCE1', 'LTCE2', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_issue_certificate unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while issuing the certificate: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
