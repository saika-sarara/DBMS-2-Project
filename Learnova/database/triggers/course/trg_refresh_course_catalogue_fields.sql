-- =========================================================
-- trg_refresh_course_catalogue_fields
--
-- TRIGGER for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_refresh_course_catalogue_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_slug TEXT;
BEGIN
    -- Difficulty values are stored consistently in uppercase.
    NEW.difficulty :=
        UPPER(
            COALESCE(
                NULLIF(BTRIM(NEW.difficulty), ''),
                'BEGINNER'
            )
        );

    -- Generate a slug automatically when one was not provided.
    IF NEW.slug IS NULL OR BTRIM(NEW.slug) = '' THEN
        v_slug :=
            TRIM(
                BOTH '-' FROM
                REGEXP_REPLACE(
                    LOWER(NEW.title),
                    '[^a-z0-9]+',
                    '-',
                    'g'
                )
            );

        IF v_slug IS NULL OR v_slug = '' THEN
            v_slug := 'course';
        END IF;

        NEW.slug :=
            LEFT(v_slug, 220)
            || '-'
            || NEW.id::TEXT;
    ELSE
        -- Normalize a manually provided slug.
        v_slug :=
            TRIM(
                BOTH '-' FROM
                REGEXP_REPLACE(
                    LOWER(BTRIM(NEW.slug)),
                    '[^a-z0-9]+',
                    '-',
                    'g'
                )
            );

        IF v_slug IS NULL OR v_slug = '' THEN
            v_slug := 'course-' || NEW.id::TEXT;
        END IF;

        NEW.slug := LEFT(v_slug, 255);
    END IF;

    -- Automatically record the first publication time.
    IF TG_OP = 'INSERT'
       AND NEW.status = 'PUBLISHED'
    THEN
        NEW.published_at :=
            COALESCE(
                NEW.published_at,
                CURRENT_TIMESTAMP
            );
    ELSIF TG_OP = 'UPDATE'
          AND NEW.status = 'PUBLISHED'
          AND OLD.status IS DISTINCT FROM 'PUBLISHED'
    THEN
        NEW.published_at :=
            COALESCE(
                NEW.published_at,
                CURRENT_TIMESTAMP
            );
    END IF;

    -- Keep the update timestamp current.
    IF TG_OP = 'UPDATE' THEN
        NEW.updated_at := CURRENT_TIMESTAMP;
    END IF;

    -- Build the weighted full-text search vector.
    NEW.search_vector :=
        SETWEIGHT(
            TO_TSVECTOR(
                'english',
                COALESCE(NEW.title, '')
            ),
            'A'
        )
        ||
        SETWEIGHT(
            TO_TSVECTOR(
                'english',
                COALESCE(NEW.short_description, '')
            ),
            'B'
        )
        ||
        SETWEIGHT(
            TO_TSVECTOR(
                'english',
                COALESCE(NEW.description, '')
            ),
            'C'
        )
        ||
        SETWEIGHT(
            TO_TSVECTOR(
                'english',
                COALESCE(NEW.difficulty, '')
            ),
            'D'
        );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_refresh_course_catalogue_fields
BEFORE INSERT OR UPDATE OF
    title,
    slug,
    short_description,
    description,
    difficulty,
    status,
    published_at
ON public.courses
FOR EACH ROW
EXECUTE FUNCTION public.fn_refresh_course_catalogue_fields();
