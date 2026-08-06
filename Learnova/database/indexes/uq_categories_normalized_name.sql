-- =========================================================
-- uq_categories_normalized_name
--
-- INDEX for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Normalized-name uniqueness
-- Closes the only real gap between the migration files and the
-- live database: category names must be unique ignoring case and
-- surrounding whitespace (e.g. "Database" vs "database").

CREATE UNIQUE INDEX uq_categories_normalized_name
    ON public.categories (lower(btrim(name)));
