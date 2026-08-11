-- =========================================================
-- idx_course_prerequisites_course
--
-- INDEX for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 7. Prerequisite indexes

CREATE INDEX IF NOT EXISTS idx_course_prerequisites_course
    ON public.course_prerequisites (course_id);
