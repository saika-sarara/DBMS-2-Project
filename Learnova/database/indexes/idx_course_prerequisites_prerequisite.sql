-- =========================================================
-- idx_course_prerequisites_prerequisite
--
-- INDEX for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_course_prerequisites_prerequisite
    ON public.course_prerequisites (prerequisite_course_id);
