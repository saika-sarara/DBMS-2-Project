-- =========================================================
-- trg_audit_course_prerequisites
--
-- TRIGGER for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
DROP TRIGGER IF EXISTS trg_audit_course_prerequisites ON public.course_prerequisites;

CREATE TRIGGER trg_audit_course_prerequisites
AFTER INSERT OR UPDATE OR DELETE ON public.course_prerequisites
FOR EACH ROW
EXECUTE FUNCTION public.fn_audit_trigger();
