-- =========================================================
-- fn_course_first_lesson_id
--
-- FUNCTION for the progress feature.
-- Source of truth: progress.sql (V7). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 2. Progress calculation functions

CREATE OR REPLACE FUNCTION public.fn_course_first_lesson_id(p_course_id BIGINT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_first_lesson_id BIGINT;
BEGIN
    SELECT id
    INTO v_first_lesson_id
    FROM public.lessons
    WHERE course_id = p_course_id
    ORDER BY sequence_order ASC, id ASC
    LIMIT 1;

    RETURN v_first_lesson_id;
END;
$$;
