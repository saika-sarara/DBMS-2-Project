-- =========================================================
-- idx_courses_search_vector
--
-- INDEX for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 2. Catalogue indexes
-- Fast PostgreSQL full-text search.

CREATE INDEX idx_courses_search_vector
    ON public.courses
    USING GIN (search_vector);
