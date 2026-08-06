-- =========================================================
-- trg_reviews_set_updated_at
--
-- TRIGGER for the review feature.
-- Source of truth: review.sql (V11). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE TRIGGER trg_reviews_set_updated_at
BEFORE UPDATE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();
