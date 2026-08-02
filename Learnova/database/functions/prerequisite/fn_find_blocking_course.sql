-- =========================================================
-- fn_find_blocking_course
--
-- Returns the first unsatisfied prerequisite course for the
-- student, or an empty set when every prerequisite is satisfied.
-- Used by access checks to tell the student what still blocks
-- a course.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_find_blocking_course(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    blocking_course_id    BIGINT,
    blocking_course_title TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.title::TEXT
    FROM course_prerequisites cp
    JOIN courses c ON c.id = cp.prerequisite_course_id
    WHERE cp.course_id = p_course_id
      AND NOT fn_prerequisite_satisfied(p_student_id, cp.prerequisite_course_id)
    ORDER BY c.id
    LIMIT 1;

    RETURN;
END;
$$;
