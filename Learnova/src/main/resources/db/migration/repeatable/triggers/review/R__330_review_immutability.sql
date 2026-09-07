-- ============================================================
-- Learnova
-- Review immutability
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_reviews_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$