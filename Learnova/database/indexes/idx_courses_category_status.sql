-- =========================================================
-- idx_courses_category_status
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX idx_courses_category_status
    ON public.courses (category_id, status);
