-- =========================================================
-- trg_audit_reviews
--
-- TRIGGER for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
DROP TRIGGER IF EXISTS trg_audit_reviews ON public.reviews;

CREATE TRIGGER trg_audit_reviews
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.fn_audit_trigger();
