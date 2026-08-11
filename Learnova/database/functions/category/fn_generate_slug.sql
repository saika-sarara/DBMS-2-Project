-- =========================================================
-- fn_generate_slug
--
-- FUNCTION for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- V3: Categories
-- All schema for the category feature in one file:
--   * slug helpers (fn_generate_slug / fn_generate_unique_course_slug)
--   * the categories table (including slug + updated_at)
--   * the three default catalogue categories
--   * the DB-enforced category business rules (V14 reconcile)
--   * admin category procedures
--   * uq_categories_normalized_name -- the unique index on
--     lower(btrim(name)) that the legacy migrations never shipped
--     but the live database had. Added here to close the gap.
-- 1. Slug helpers

CREATE OR REPLACE FUNCTION public.fn_generate_slug(p_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_slug TEXT;
BEGIN
    v_slug := TRIM(
        BOTH '-' FROM
        REGEXP_REPLACE(
            LOWER(COALESCE(p_text, '')),
            '[^a-z0-9]+',
            '-',
            'g'
        )
    );

    IF v_slug IS NULL OR v_slug = '' THEN
        v_slug := 'item';
    END IF;

    RETURN LEFT(v_slug, 150);
END;
$$;
