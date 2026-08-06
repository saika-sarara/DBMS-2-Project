-- =========================================================
-- sp_update_category
--
-- PROCEDURE for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_update_category(
    p_actor_id     BIGINT,
    p_category_id  BIGINT,
    p_name         VARCHAR,
    p_description  TEXT,
    p_is_active    BOOLEAN
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
DECLARE
    v_old_name VARCHAR(100);
BEGIN
    IF NOT public.fn_user_has_role(p_actor_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can manage categories.'
            USING ERRCODE = 'LTC10';
    END IF;

    SELECT name INTO v_old_name
    FROM public.categories WHERE id = p_category_id;

    IF v_old_name IS NULL THEN
        RAISE EXCEPTION 'LTC15: Category % does not exist.', p_category_id
            USING ERRCODE = 'LTC15';
    END IF;

    IF p_name IS NULL OR BTRIM(p_name) = '' THEN
        RAISE EXCEPTION 'LTC13: Category name is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    UPDATE public.categories
    SET name = BTRIM(p_name),
        slug = public.fn_generate_slug(p_name),
        description = p_description,
        is_active = COALESCE(p_is_active, TRUE)
    WHERE id = p_category_id
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
        IF SQLSTATE IN ('LTC10', 'LTC15', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_category unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the category: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
