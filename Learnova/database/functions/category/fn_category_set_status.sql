-- =========================================================
-- fn_category_set_status
--
-- FUNCTION for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_category_set_status(
    p_category_id bigint,
    p_is_active boolean
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

    IF p_is_active IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'P2002',
                MESSAGE = 'CATEGORY_STATUS_REQUIRED',
                DETAIL =
                    'Category status must be either true or false.';
    END IF;

    UPDATE public.categories
    SET is_active = p_is_active
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
END;
$function$;
