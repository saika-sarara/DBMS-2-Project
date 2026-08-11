-- =========================================================
-- idx_lessons_course
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX idx_lessons_course
    ON public.lessons (course_id);
