-- =========================================================
-- idx_categories_active_name
--
-- INDEX for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Fast loading of active categories.

CREATE INDEX idx_categories_active_name
    ON public.categories (is_active, name);
