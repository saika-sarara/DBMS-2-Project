-- =========================================================
-- idx_courses_pending_review
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Pending-review queue for the admin moderation screen.

CREATE INDEX idx_courses_pending_review
    ON public.courses (status, submitted_at DESC)
    WHERE status = 'PENDING_REVIEW';
