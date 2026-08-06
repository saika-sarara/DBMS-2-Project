-- =========================================================
-- fn_category_list_active
--
-- FUNCTION for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_category_list_active()
RETURNS SETOF public.categories
LANGUAGE sql
STABLE
AS $function$
    SELECT category.*
    FROM public.categories AS category
    WHERE category.is_active = TRUE
    ORDER BY
        LOWER(category.name),
        category.id;
$function$;
