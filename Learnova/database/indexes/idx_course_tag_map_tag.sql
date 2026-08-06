-- =========================================================
-- idx_course_tag_map_tag
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX idx_course_tag_map_tag
    ON public.course_tag_map (tag_id);
