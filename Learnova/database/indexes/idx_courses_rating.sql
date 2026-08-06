-- =========================================================
-- idx_courses_rating
--
-- INDEX for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Fast sorting by rating.

CREATE INDEX idx_courses_rating
    ON public.courses (
        avg_rating DESC,
        review_count DESC
    );
