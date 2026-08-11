-- =========================================================
-- idx_track_courses_sequence
--
-- INDEX for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_track_courses_sequence
    ON public.track_courses (track_id, sequence_order);
