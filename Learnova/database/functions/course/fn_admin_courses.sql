-- =========================================================
-- fn_admin_courses
--
-- FUNCTION for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_admin_courses(p_status_filter VARCHAR DEFAULT NULL)
RETURNS TABLE (
    course_id        BIGINT,
    title            VARCHAR,
    slug             VARCHAR,
    status           VARCHAR,
    difficulty       VARCHAR,
    category_id      BIGINT,
    category_name    VARCHAR,
    instructor_id    BIGINT,
    instructor_name  TEXT,
    short_description VARCHAR,
    description      TEXT,
    thumbnail_url    TEXT,
    module_count     BIGINT,
    lesson_count     BIGINT,
    rejection_reason TEXT,
    submitted_at     TIMESTAMPTZ,
    published_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        c.id,
        c.title,
        c.slug,
        c.status,
        c.difficulty,
        c.category_id,
        COALESCE(cat.name, 'Uncategorized')::VARCHAR,
        c.instructor_id,
        CONCAT_WS(' ', u.first_name, u.last_name),
        c.short_description,
        c.description,
        c.thumbnail_url,
        (SELECT COUNT(*)::BIGINT FROM public.modules m WHERE m.course_id = c.id),
        (SELECT COUNT(*)::BIGINT FROM public.lessons l WHERE l.course_id = c.id),
        c.rejection_reason,
        c.submitted_at,
        c.published_at,
        c.created_at,
        c.updated_at
    FROM public.courses c
    LEFT JOIN public.categories cat ON cat.id = c.category_id
    LEFT JOIN public.users u ON u.id = c.instructor_id
    WHERE (p_status_filter IS NULL
           OR BTRIM(p_status_filter) = ''
           OR c.status = UPPER(BTRIM(p_status_filter)))
    ORDER BY
        CASE c.status
            WHEN 'PENDING_REVIEW' THEN 0
            WHEN 'DRAFT' THEN 1
            WHEN 'REJECTED' THEN 2
            ELSE 3
        END ASC,
        c.updated_at DESC,
        c.id DESC;
$$;
