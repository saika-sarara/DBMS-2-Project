-- =========================================================
-- trg_audit_certificates
--
-- TRIGGER for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
DROP TRIGGER IF EXISTS trg_audit_certificates ON public.certificates;

CREATE TRIGGER trg_audit_certificates
AFTER INSERT OR UPDATE OR DELETE ON public.certificates
FOR EACH ROW
EXECUTE FUNCTION public.fn_audit_trigger();
