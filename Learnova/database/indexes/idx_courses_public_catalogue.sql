-- =========================================================
-- idx_courses_public_catalogue
--
-- INDEX for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Fast filtering of published courses.

CREATE INDEX idx_courses_public_catalogue
    ON public.courses (
        status,
        category_id,
        difficulty,
        published_at DESC
    );
