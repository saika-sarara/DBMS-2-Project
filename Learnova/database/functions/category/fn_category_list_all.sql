-- =========================================================
-- fn_category_list_all
--
-- FUNCTION for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_category_list_all()
RETURNS SETOF public.categories
LANGUAGE sql
STABLE
AS $function$
    SELECT category.*
    FROM public.categories AS category
    ORDER BY
        category.is_active DESC,
        LOWER(category.name),
        category.id;
$function$;
