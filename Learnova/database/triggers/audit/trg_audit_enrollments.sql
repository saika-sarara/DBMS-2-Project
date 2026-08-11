-- =========================================================
-- trg_audit_enrollments
--
-- TRIGGER for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
DROP TRIGGER IF EXISTS trg_audit_enrollments ON public.enrollments;

CREATE TRIGGER trg_audit_enrollments
AFTER INSERT OR UPDATE OR DELETE ON public.enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_audit_trigger();
