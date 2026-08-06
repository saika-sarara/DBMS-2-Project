-- =========================================================
-- idx_courses_title_trgm
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Autocomplete-friendly trigram search on course titles.

CREATE INDEX idx_courses_title_trgm
    ON public.courses USING GIN (title gin_trgm_ops);
