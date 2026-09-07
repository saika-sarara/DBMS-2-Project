-- ============================================================
-- Learnova
-- Review immutability
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_reviews_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
IF TG_OP = 'DELETE' AND pg_trigger_depth() > 1 THEN
RETURN OLD;

END IF;
IF TG_OP = 'UPDATE' THEN
RAISE EXCEPTION 'LTR04: Submitted reviews cannot be edited.' USING ERRCODE = 'LTR04';

END IF;
IF TG_OP = 'DELETE' THEN
RAISE EXCEPTION 'LTR04: Submitted reviews cannot be deleted.' USING ERRCODE = 'LTR04';
END IF;
RETURN COALESCE(NEW, OLD);
END;
$$;
DROP TRIGGER IF EXISTS trg_reviews_immutable ON public.reviews;
CREATE TRIGGER trg_reviews_immutable
BEFORE UPDATE OR DELETE
ON public.reviews

FOR EACH ROW
EXECUTE FUNCTION public.fn_reviews_immutable();