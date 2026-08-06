-- =========================================================
-- sp_update_course_basic_info
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_update_course_basic_info(
    p_actor_id        BIGINT,
    p_course_id       BIGINT,
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
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(p_course_id) THEN
        RAISE EXCEPTION 'LTC12: Published or archived courses cannot be edited.'
            USING ERRCODE = 'LTC12';
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

    UPDATE public.courses
    SET category_id = p_category_id,
        title = BTRIM(p_title),
        short_description = p_short_description,
        description = p_description,
        difficulty = v_difficulty,
        thumbnail_url = p_thumbnail_url
    WHERE id = p_course_id
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
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC13', '23505', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_update_course_basic_info unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
