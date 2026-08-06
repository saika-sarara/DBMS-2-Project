-- =========================================================
-- fn_prerequisite_satisfied
--
-- FUNCTION for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 2. Per-student prerequisite rules
-- A single prerequisite course is satisfied by the student when the
-- course was completed OR its bypass quiz was passed (a bypass record
-- is keyed on the prerequisite course, for any target course).

CREATE OR REPLACE FUNCTION public.fn_prerequisite_satisfied(
    p_student_id            BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.enrollments
        WHERE user_id = p_student_id
          AND course_id = p_prerequisite_course_id
          AND status = 'completed'
    ) THEN
        RETURN TRUE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.course_bypasses
        WHERE user_id = p_student_id
          AND prerequisite_course_id = p_prerequisite_course_id
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;
