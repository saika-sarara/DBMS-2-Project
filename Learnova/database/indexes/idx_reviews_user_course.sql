-- =========================================================
-- idx_reviews_user_course
--
-- INDEX for the review feature.
-- Source of truth: review.sql (V11). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_reviews_user_course
    ON public.reviews (user_id, course_id);
