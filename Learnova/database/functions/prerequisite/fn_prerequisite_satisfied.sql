-- =========================================================
-- fn_prerequisite_satisfied  (PREREQUISITE MODULE)
--
-- Returns TRUE when a student has satisfied a single prerequisite
-- course, either by completing the course or by passing its
-- bypass quiz (recorded in course_bypasses).
-- =========================================================

CREATE OR REPLACE FUNCTION fn_prerequisite_satisfied(
    p_student_id BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM enrollments
        WHERE user_id = p_student_id
          AND course_id = p_prerequisite_course_id
          AND status = 'completed'
    ) THEN
        RETURN TRUE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM course_bypasses
        WHERE user_id = p_student_id
          AND course_id = p_prerequisite_course_id
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;
