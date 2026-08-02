-- =========================================================
-- fn_check_prerequisites_met
--
-- AND-based prerequisite rule: every prerequisite course of the
-- target course must be satisfied by the student (completed or
-- bypassed). Returns FALSE as soon as any prerequisite is missing.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_check_prerequisites_met(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_missing_prereqs INT;
BEGIN
    SELECT COUNT(*)
    INTO v_missing_prereqs
    FROM course_prerequisites cp
    WHERE cp.course_id = p_course_id
      AND NOT fn_prerequisite_satisfied(p_student_id, cp.prerequisite_course_id);

    RETURN v_missing_prereqs = 0;
END;
$$;
