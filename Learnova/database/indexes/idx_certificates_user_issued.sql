-- =========================================================
-- idx_certificates_user_issued
--
-- INDEX for the certificate feature.
-- Source of truth: certificate.sql (V12). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 5. Certificate indexes

CREATE INDEX IF NOT EXISTS idx_certificates_user_issued
    ON public.certificates (user_id, issued_at DESC);
