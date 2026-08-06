-- =========================================================
-- idx_reviews_course_rating
--
-- INDEX for the review feature.
-- Source of truth: review.sql (V11). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Review indexes

CREATE INDEX IF NOT EXISTS idx_reviews_course_rating
    ON public.reviews (course_id, rating);
