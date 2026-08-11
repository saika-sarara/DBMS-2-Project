-- =========================================================
-- idx_lesson_progress_enrollment_status
--
-- INDEX for the progress feature.
-- Source of truth: progress.sql (V7). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Progress indexes

CREATE INDEX IF NOT EXISTS idx_lesson_progress_enrollment_status
    ON public.lesson_progress (enrollment_id, status);
