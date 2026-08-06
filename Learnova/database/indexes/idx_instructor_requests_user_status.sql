-- =========================================================
-- idx_instructor_requests_user_status
--
-- INDEX for the auth feature.
-- Source of truth: auth.sql (V2). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX idx_instructor_requests_user_status
    ON public.instructor_requests (user_id, status);
