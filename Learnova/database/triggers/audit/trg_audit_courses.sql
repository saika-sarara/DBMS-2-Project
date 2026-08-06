-- =========================================================
-- trg_audit_courses
--
-- TRIGGER for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
DROP TRIGGER IF EXISTS trg_audit_courses ON public.courses;

CREATE TRIGGER trg_audit_courses
AFTER INSERT OR UPDATE OR DELETE ON public.courses
FOR EACH ROW
EXECUTE FUNCTION public.fn_audit_trigger();
