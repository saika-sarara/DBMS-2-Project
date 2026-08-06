-- =========================================================
-- idx_courses_status
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 13. Course indexes

CREATE INDEX idx_courses_status
    ON public.courses (status);
