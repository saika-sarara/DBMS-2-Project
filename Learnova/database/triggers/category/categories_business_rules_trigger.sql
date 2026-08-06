-- =========================================================
-- categories_business_rules_trigger
--
-- TRIGGER for the category feature.
-- Source of truth: categories.sql (V3). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.trg_enforce_category_business_rules()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    /*
     * Category name is mandatory.
     */
    IF NEW.name IS NULL OR BTRIM(NEW.name) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'P2001',
                MESSAGE = 'CATEGORY_NAME_REQUIRED',
                DETAIL =
                    'Category name cannot be null or blank.';
    END IF;

    /*
     * Normalize values before saving.
     */
    NEW.name := BTRIM(NEW.name);
    NEW.description := NULLIF(BTRIM(NEW.description), '');

    /*
     * PostgreSQL owns timestamp maintenance.
     */
    NEW.updated_at := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE TRIGGER categories_business_rules_trigger
BEFORE INSERT OR UPDATE ON public.categories
FOR EACH ROW
EXECUTE FUNCTION public.trg_enforce_category_business_rules();
