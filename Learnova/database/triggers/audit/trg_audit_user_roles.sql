-- =========================================================
-- trg_audit_user_roles
--
-- TRIGGER for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
DROP TRIGGER IF EXISTS trg_audit_user_roles ON public.user_roles;

CREATE TRIGGER trg_audit_user_roles
AFTER INSERT OR UPDATE OR DELETE ON public.user_roles
FOR EACH ROW
EXECUTE FUNCTION public.fn_audit_trigger();
