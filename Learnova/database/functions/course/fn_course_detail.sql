-- =========================================================
-- fn_course_detail
--
-- FUNCTION for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 7. Course detail

CREATE OR REPLACE FUNCTION public.fn_course_detail(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    course_id                  BIGINT,
    title                      VARCHAR,
    slug                       VARCHAR,
    short_description          VARCHAR,
    description                TEXT,
    difficulty                 VARCHAR,
    thumbnail_url              TEXT,
    category_id                BIGINT,
    category_name              VARCHAR,
    instructor_id              BIGINT,
    instructor_name            TEXT,
    avg_rating                 NUMERIC,
    review_count               INTEGER,
    total_lessons              INTEGER,
    estimated_duration_minutes INTEGER,
    total_modules              BIGINT,
    published_at               TIMESTAMPTZ,
    created_at                 TIMESTAMPTZ,
    card_status                TEXT,
    is_locked                  BOOLEAN,
    is_enrolled                BOOLEAN,
    is_completed               BOOLEAN,
    lock_reason                TEXT,
    tags                       TEXT[]
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    SELECT c.status INTO v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        RETURN;
    END IF;

    -- Draft/pending/rejected/archived courses are visible only to the
    -- owning instructor or to administrators.
    IF v_status <> 'PUBLISHED' THEN
        IF p_student_id IS NULL
           OR (NOT public.fn_course_is_owned_by(p_course_id, p_student_id)
               AND NOT public.fn_user_has_role(p_student_id, 'ADMIN')) THEN
            RETURN;
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.title,
        c.slug,
        c.short_description,
        c.description,
        c.difficulty,
        c.thumbnail_url,
        c.category_id,
        COALESCE(cat.name, 'Uncategorized')::VARCHAR,
        c.instructor_id,
        CONCAT_WS(' ', u.first_name, u.last_name),
        c.avg_rating,
        c.review_count,
        c.total_lessons,
        c.estimated_duration_minutes,
        (SELECT COUNT(*)::BIGINT FROM public.modules m WHERE m.course_id = c.id),
        c.published_at,
        c.created_at,
        cs.card_status,
        cs.is_locked,
        cs.is_enrolled,
        cs.is_completed,
        cs.lock_reason,
        public.fn_course_tag_list(c.id)
    FROM public.courses c
    LEFT JOIN public.categories cat ON cat.id = c.category_id
    LEFT JOIN public.users u ON u.id = c.instructor_id
    CROSS JOIN LATERAL public.fn_course_card_status(p_student_id, c.id) cs
    WHERE c.id = p_course_id;
END;
$$;
