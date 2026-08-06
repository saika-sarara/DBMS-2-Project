-- =========================================================
-- idx_audit_logs_actor
--
-- INDEX for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor
    ON public.audit_logs (performed_by);
