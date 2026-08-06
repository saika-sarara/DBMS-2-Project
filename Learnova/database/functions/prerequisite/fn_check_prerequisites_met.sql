-- =========================================================
-- fn_check_prerequisites_met
--
-- FUNCTION for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- AND-based rule: every prerequisite course of the target course must
-- be satisfied by the student. Returns FALSE as soon as one is missing.

CREATE OR REPLACE FUNCTION public.fn_check_prerequisites_met(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_missing_prereqs INT;
BEGIN
    SELECT COUNT(*)
    INTO v_missing_prereqs
    FROM public.course_prerequisites cp
    WHERE cp.course_id = p_course_id
      AND NOT public.fn_prerequisite_satisfied(p_student_id, cp.prerequisite_course_id);

    RETURN v_missing_prereqs = 0;
END;
$$;
