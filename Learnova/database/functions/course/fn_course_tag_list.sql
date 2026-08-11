-- =========================================================
-- fn_course_tag_list
--
-- FUNCTION for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_course_tag_list(p_course_id BIGINT)
RETURNS TEXT[]
LANGUAGE sql
STABLE
AS $$
    SELECT ARRAY(
        SELECT ct.name
        FROM public.course_tag_map ctm
        JOIN public.course_tags ct ON ct.id = ctm.tag_id
        WHERE ctm.course_id = p_course_id
        ORDER BY ct.name ASC
    );
$$;
