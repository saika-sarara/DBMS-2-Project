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