-- =========================================================
-- idx_course_bypasses_user
--
-- INDEX for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_course_bypasses_user
    ON public.course_bypasses (user_id);
