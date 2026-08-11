-- =========================================================
-- idx_instructor_requests_status_created
--
-- INDEX for the auth feature.
-- Source of truth: auth.sql (V2). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX idx_instructor_requests_status_created
    ON public.instructor_requests (status, created_at);
