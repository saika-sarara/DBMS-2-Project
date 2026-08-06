-- =========================================================
-- V3: Categories
--
-- All schema for the category feature in one file:
--   * slug helpers (fn_generate_slug / fn_generate_unique_course_slug)
--   * the categories table (including slug + updated_at)
--   * the three default catalogue categories
--   * the DB-enforced category business rules (V14 reconcile)
--   * admin category procedures
--   * uq_categories_normalized_name -- the unique index on
--     lower(btrim(name)) that the legacy migrations never shipped
--     but the live database had. Added here to close the gap.
-- =========================================================

-- =========================================================
-- 1. Slug helpers
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_generate_slug(p_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_slug TEXT;
BEGIN
    v_slug := TRIM(
        BOTH '-' FROM
        REGEXP_REPLACE(
            LOWER(COALESCE(p_text, '')),
            '[^a-z0-9]+',
            '-',
            'g'
        )
    );

    IF v_slug IS NULL OR v_slug = '' THEN
        v_slug := 'item';
    END IF;

    RETURN LEFT(v_slug, 150);
END;
$$;

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


-- =========================================================
-- 2. Categories table
-- =========================================================

CREATE TABLE public.categories (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    slug        VARCHAR(150) NOT NULL,
    description TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_categories_name
        UNIQUE (name),

    CONSTRAINT uq_categories_slug
        UNIQUE (slug)
);

CREATE TRIGGER trg_categories_set_updated_at
BEFORE UPDATE ON public.categories
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================================
-- 3. Default catalogue categories
-- =========================================================

INSERT INTO public.categories (name, slug, description)
VALUES
    ('Database',       'database',       'Relational and NoSQL data modeling, SQL and query optimization.'),
    ('Programming',    'programming',    'Web and general-purpose programming languages.'),
    ('Data Science',   'data-science',   'Data analysis, machine learning and visualization.')
ON CONFLICT DO NOTHING;


-- =========================================================
-- 4. Normalized-name uniqueness
--
-- Closes the only real gap between the migration files and the
-- live database: category names must be unique ignoring case and
-- surrounding whitespace (e.g. "Database" vs "database").
-- =========================================================

CREATE UNIQUE INDEX uq_categories_normalized_name
    ON public.categories (lower(btrim(name)));

-- Fast loading of active categories.
CREATE INDEX idx_categories_active_name
    ON public.categories (is_active, name);


-- =========================================================
-- 5. Category business rules (database-owned integrity)
-- =========================================================

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


-- =========================================================
-- 6. Admin category procedures
-- =========================================================

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
