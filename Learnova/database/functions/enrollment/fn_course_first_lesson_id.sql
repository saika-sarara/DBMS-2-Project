-- =========================================================
-- fn_course_first_lesson_id
--
-- Returns the id of the first lesson of a course, using the
-- lesson sequence defined by the course module. Only the first
-- lesson can ever be unlocked for a student.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_course_first_lesson_id(p_course_id BIGINT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_first_lesson_id BIGINT;
BEGIN
    SELECT id
    INTO v_first_lesson_id
    FROM lessons
    WHERE course_id = p_course_id
    ORDER BY sequence_order ASC, id ASC
    LIMIT 1;

    RETURN v_first_lesson_id;
END;
$$;
