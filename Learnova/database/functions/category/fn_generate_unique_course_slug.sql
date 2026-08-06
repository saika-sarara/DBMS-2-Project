-- =========================================================
-- fn_generate_unique_course_slug
--
-- FUNCTION for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_generate_unique_course_slug(p_title TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_base    TEXT;
    v_slug    TEXT;
    v_counter INTEGER := 1;
BEGIN
    v_base := public.fn_generate_slug(p_title);

    IF v_base = 'item' THEN
        v_base := 'course';
    END IF;

    v_slug := v_base;

    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.courses WHERE slug = v_slug
        ) THEN
            RETURN v_slug;
        END IF;

        v_counter := v_counter + 1;
        v_slug := LEFT(v_base, 145) || '-' || v_counter;
    END LOOP;
END;
$$;
