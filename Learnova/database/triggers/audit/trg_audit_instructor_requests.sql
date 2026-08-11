-- =========================================================
-- trg_audit_instructor_requests
--
-- TRIGGER for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
DROP TRIGGER IF EXISTS trg_audit_instructor_requests ON public.instructor_requests;

CREATE TRIGGER trg_audit_instructor_requests
AFTER INSERT OR UPDATE OR DELETE ON public.instructor_requests
FOR EACH ROW
EXECUTE FUNCTION public.fn_audit_trigger();
