-- =========================================================
-- sp_create_course_draft
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 8. Course lifecycle procedures

CREATE OR REPLACE FUNCTION public.sp_create_course_draft(
    p_instructor_id   BIGINT,
    p_category_id     BIGINT,
    p_title           VARCHAR,
    p_short_description VARCHAR,
    p_description     TEXT,
    p_difficulty      VARCHAR,
    p_thumbnail_url   TEXT
)
RETURNS TABLE (
    course_id        BIGINT,
    title            VARCHAR,
    slug             VARCHAR,
    status           VARCHAR,
    difficulty       VARCHAR,
    category_id      BIGINT,
    instructor_id    BIGINT,
    short_description VARCHAR,
    description      TEXT,
    thumbnail_url    TEXT,
    created_at       TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_difficulty VARCHAR(20);
BEGIN
    IF NOT public.fn_user_is_instructor_or_admin(p_instructor_id) THEN
        RAISE EXCEPTION 'LTC10: Only instructors and administrators can create courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    IF p_title IS NULL OR BTRIM(p_title) = '' THEN
        RAISE EXCEPTION 'LTC13: Course title is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    IF p_category_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.categories WHERE id = p_category_id AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'LTC13: A valid active category is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    v_difficulty := UPPER(COALESCE(NULLIF(BTRIM(p_difficulty), ''), 'BEGINNER'));

    IF v_difficulty NOT IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED') THEN
        RAISE EXCEPTION 'LTC13: difficulty must be beginner, intermediate or advanced.'
            USING ERRCODE = 'LTC13';
    END IF;

    INSERT INTO public.courses (
        instructor_id,
        category_id,
        title,
        slug,
        short_description,
        description,
        difficulty,
        status,
        thumbnail_url
    )
    VALUES (
        p_instructor_id,
        p_category_id,
        BTRIM(p_title),
        public.fn_generate_unique_course_slug(p_title),
        p_short_description,
        p_description,
        v_difficulty,
        'DRAFT',
        p_thumbnail_url
    )
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.difficulty,
        public.courses.category_id,
        public.courses.instructor_id,
        public.courses.short_description,
        public.courses.description,
        public.courses.thumbnail_url,
        public.courses.created_at,
        public.courses.updated_at
    INTO course_id, title, slug, status, difficulty, category_id, instructor_id,
         short_description, description, thumbnail_url, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC13', '23505', '23502', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_create_course_draft unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while creating the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
