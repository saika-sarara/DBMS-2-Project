-- =========================================================
-- idx_audit_logs_performed_at
--
-- INDEX for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_audit_logs_performed_at
    ON public.audit_logs (performed_at DESC);
