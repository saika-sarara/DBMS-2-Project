-- =========================================================
-- sp_delete_category
--
-- PROCEDURE for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_delete_category(
    p_actor_id    BIGINT,
    p_category_id BIGINT
)
RETURNS TABLE (category_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT public.fn_user_has_role(p_actor_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can manage categories.'
            USING ERRCODE = 'LTC10';
    END IF;

    IF EXISTS (SELECT 1 FROM public.courses WHERE category_id = p_category_id) THEN
        RAISE EXCEPTION 'LTC16: Category cannot be deleted because courses reference it.'
            USING ERRCODE = 'LTC16';
    END IF;

    DELETE FROM public.categories WHERE id = p_category_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'LTC15: Category % does not exist.', p_category_id
            USING ERRCODE = 'LTC15';
    END IF;

    category_id := p_category_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC15', 'LTC16') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_delete_category unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while deleting the category: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
