-- =========================================================
-- idx_track_enrollments_user_status
--
-- INDEX for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_track_enrollments_user_status
    ON public.track_enrollments (user_id, status);
