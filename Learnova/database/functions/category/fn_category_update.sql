-- =========================================================
-- fn_category_update
--
-- FUNCTION for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_category_update(
    p_category_id bigint,
    p_name text,
    p_description text
)
RETURNS public.categories
LANGUAGE plpgsql
AS $function$
DECLARE
    updated_category public.categories%ROWTYPE;
BEGIN
    IF p_category_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'P2004',
                MESSAGE = 'CATEGORY_NOT_FOUND',
                DETAIL =
                    'Category ID cannot be null.';
    END IF;

    UPDATE public.categories
    SET
        name = p_name,
        description = p_description
    WHERE id = p_category_id
    RETURNING *
    INTO updated_category;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'P2004',
                MESSAGE = 'CATEGORY_NOT_FOUND',
                DETAIL =
                    'No category exists with ID '
                    || p_category_id::TEXT
                    || '.';
    END IF;

    RETURN updated_category;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'P2003',
                MESSAGE = 'CATEGORY_NAME_ALREADY_EXISTS',
                DETAIL =
                    'Another category already uses the same normalized name.';
END;
$function$;
