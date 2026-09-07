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