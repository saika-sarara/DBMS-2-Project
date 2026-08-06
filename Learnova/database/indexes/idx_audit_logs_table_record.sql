-- =========================================================
-- idx_audit_logs_table_record
--
-- INDEX for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 5. Audit indexes

CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record
    ON public.audit_logs (table_name, record_id);
