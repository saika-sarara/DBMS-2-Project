-- ============================================================
-- Learnova
-- Current prerequisite access functions
--
-- Historical implementations exist in V9 and V25.
-- This repeatable migration owns the CURRENT executable
-- prerequisite access behavior.
-- ============================================================


-- ============================================================
-- 1. Score-aware prerequisite satisfaction
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_prerequisite_satisfied(
    p_student_id BIGINT,
    p_prerequisite_course_id BIGINT,
    p_required_min_score NUMERIC(5,2) DEFAULT 60.00
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    /*
     * An explicit prerequisite bypass satisfies the
     * prerequisite regardless of recorded course score.
     */
    IF EXISTS (
        SELECT 1
        FROM public.course_bypasses cb
        WHERE cb.user_id = p_student_id
          AND cb.prerequisite_course_id =
              p_prerequisite_course_id
    ) THEN
        RETURN TRUE;
    END IF;


    /*
     * Normal completion requires both:
     *
     *   1. completed enrollment
     *   2. final score >= configured prerequisite minimum
     */
    IF EXISTS (
        SELECT 1

        FROM public.enrollments e

        WHERE e.user_id = p_student_id

          AND e.course_id =
              p_prerequisite_course_id

          AND e.status = 'completed'

          AND COALESCE(
                  e.final_score_pct,
                  0
              )
              >=
              COALESCE(
                  p_required_min_score,
                  60.00
              )
    ) THEN
        RETURN TRUE;
    END IF;


    RETURN FALSE;
END;
$$;


-- ============================================================
-- 2. Backward-compatible two-argument overload
--
-- V9 created this signature.
-- Keep it because historical/current DB objects may call it.
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_prerequisite_satisfied(
    p_student_id BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT public.fn_prerequisite_satisfied(
        p_student_id,
        p_prerequisite_course_id,
        60.00::NUMERIC(5,2)
    );
$$;


-- ============================================================
-- 3. All prerequisites must be satisfied
--
-- Prerequisites use AND semantics.
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_check_prerequisites_met(
    p_student_id BIGINT,
    p_course_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_missing_prerequisites INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO v_missing_prerequisites

    FROM public.course_prerequisites cp

    WHERE cp.course_id = p_course_id

      AND NOT public.fn_prerequisite_satisfied(
          p_student_id,
          cp.prerequisite_course_id,
          cp.required_min_score
      );


    RETURN v_missing_prerequisites = 0;
END;
$$;


-- ============================================================
-- 4. Find one blocking prerequisite
--
-- IMPORTANT:
-- V25 established this exact return contract.
-- Do not change the OUT column names/types here.
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_find_blocking_course(
    p_student_id BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    blocking_course_id BIGINT,
    blocking_course_title TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN

    RETURN QUERY

    SELECT
        c.id,
        c.title::TEXT

    FROM public.course_prerequisites cp

    JOIN public.courses c
      ON c.id = cp.prerequisite_course_id

    WHERE cp.course_id = p_course_id

      AND NOT public.fn_prerequisite_satisfied(
          p_student_id,
          cp.prerequisite_course_id,
          cp.required_min_score
      )

    ORDER BY c.id

    LIMIT 1;


    RETURN;
END;
$$;


-- ============================================================
-- 5. Enrollment-facing prerequisite engine contract
--
-- V6 enrollment/progress logic consumes this exact function
-- signature.
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_prerequisite_engine_course_access(
    p_student_id BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    allowed BOOLEAN,
    reason_code TEXT,
    message TEXT,
    blocking_course_id BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_blocking_course_id BIGINT;
    v_blocking_course_title TEXT;
BEGIN

    IF public.fn_check_prerequisites_met(
        p_student_id,
        p_course_id
    ) THEN

        allowed := TRUE;

        reason_code :=
            'PREREQUISITES_OK';

        message :=
            NULL;

        blocking_course_id :=
            NULL;

        RETURN NEXT;
        RETURN;

    END IF;


    SELECT
        blocking.blocking_course_id,
        blocking.blocking_course_title

    INTO
        v_blocking_course_id,
        v_blocking_course_title

    FROM public.fn_find_blocking_course(
        p_student_id,
        p_course_id
    ) blocking

    LIMIT 1;


    allowed :=
        FALSE;

    reason_code :=
        'PREREQUISITES_LOCKED';

    message :=
        'Course is locked until prerequisite "' ||
        COALESCE(
            v_blocking_course_title,
            'a required course'
        ) ||
        '" is completed or bypassed.';

    blocking_course_id :=
        v_blocking_course_id;


    RETURN NEXT;
    RETURN;

END;
$$;
