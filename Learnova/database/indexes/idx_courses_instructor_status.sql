-- =========================================================
-- idx_courses_instructor_status
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX idx_courses_instructor_status
    ON public.courses (instructor_id, status);
