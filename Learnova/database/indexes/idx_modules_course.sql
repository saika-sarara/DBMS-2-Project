-- =========================================================
-- idx_modules_course
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX idx_modules_course
    ON public.modules (course_id);
