-- =========================================================
-- fn_category_create
--
-- FUNCTION for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 5. Category business rules (database-owned integrity)

CREATE OR REPLACE FUNCTION public.fn_category_create(
    p_name text,
    p_description text
)
RETURNS public.categories
LANGUAGE plpgsql
AS $function$
DECLARE
    created_category public.categories%ROWTYPE;
BEGIN
    INSERT INTO public.categories (
        name,
        description,
        is_active
    )
    VALUES (
        p_name,
        p_description,
        TRUE
    )
    RETURNING *
    INTO created_category;

    RETURN created_category;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'P2003',
                MESSAGE = 'CATEGORY_NAME_ALREADY_EXISTS',
                DETAIL =
                    'A category with the same normalized name already exists.';
END;
$function$;
