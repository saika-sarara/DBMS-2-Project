-- =========================================================
-- sp_create_category
--
-- PROCEDURE for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 6. Admin category procedures

CREATE OR REPLACE FUNCTION public.sp_create_category(
    p_actor_id    BIGINT,
    p_name        VARCHAR,
    p_description TEXT
)
RETURNS TABLE (
    category_id   BIGINT,
    name          VARCHAR,
    slug          VARCHAR,
    description   TEXT,
    is_active     BOOLEAN,
    created_at    TIMESTAMPTZ,
    updated_at    TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT public.fn_user_has_role(p_actor_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can manage categories.'
            USING ERRCODE = 'LTC10';
    END IF;

    IF p_name IS NULL OR BTRIM(p_name) = '' THEN
        RAISE EXCEPTION 'LTC13: Category name is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    INSERT INTO public.categories (name, slug, description)
    VALUES (BTRIM(p_name), public.fn_generate_slug(p_name), p_description)
    RETURNING
        public.categories.id,
        public.categories.name,
        public.categories.slug,
        public.categories.description,
        public.categories.is_active,
        public.categories.created_at,
        public.categories.updated_at
    INTO category_id, name, slug, description, is_active, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC13', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_create_category unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while creating the category: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
