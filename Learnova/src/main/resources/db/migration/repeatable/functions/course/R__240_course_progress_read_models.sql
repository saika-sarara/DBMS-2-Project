-- =========================================================
-- 1. Course detail: expose the enrollment progress_pct
-- =========================================================
-- The progress module (V7) keeps enrollments.progress_pct + 100 exactly
-- when every lesson_progress row is 'completed' (trg_update_course_progress).
-- The lesson-view rail header needs that number; it is the authoritative,
-- trigger-maintained course progress and must not be recomputed on the client.

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
    tags                       TEXT[],
    progress_pct               NUMERIC(5,2)
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
        public.fn_course_tag_list(c.id),
        COALESCE(
            (SELECT e.progress_pct
               FROM public.enrollments e
              WHERE e.user_id = p_student_id
                AND e.course_id = c.id
              ORDER BY e.enrolled_at DESC, e.id DESC
              LIMIT 1),
            0.00
        )::NUMERIC(5,2)
    FROM public.courses c
    LEFT JOIN public.categories cat ON cat.id = c.category_id
    LEFT JOIN public.users u ON u.id = c.instructor_id
    CROSS JOIN LATERAL public.fn_course_card_status(p_student_id, c.id) cs
    WHERE c.id = p_course_id;
END;
$$;


-- =========================================================
-- 2. Syllabus: expose per-lesson pass state
-- =========================================================
-- A lesson counts as passed exactly when the student's lesson_progress row
-- is 'completed'. Passing a lesson quiz sets that state (V27); the course
-- progress % is derived from these same rows (V7). The lesson-view rail
-- therefore renders pass icons from this column instead of fanning out to
-- N quiz-status requests on the client.

CREATE OR REPLACE FUNCTION public.fn_course_syllabus(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    module_id             BIGINT,
    module_title          VARCHAR,
    module_order          INTEGER,
    lesson_id             BIGINT,
    lesson_title          VARCHAR,
    lesson_order          INTEGER,
    estimated_duration_minutes INTEGER,
    is_preview            BOOLEAN,
    lesson_access_status  TEXT,
    lesson_passed         BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_course_status VARCHAR(20);
    v_accessible    BOOLEAN;
BEGIN
    SELECT c.status INTO v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_course_status IS NULL THEN
        RETURN;
    END IF;

    IF v_course_status <> 'PUBLISHED'
       AND (p_student_id IS NULL
            OR (NOT public.fn_course_is_owned_by(p_course_id, p_student_id)
                AND NOT public.fn_user_has_role(p_student_id, 'ADMIN'))) THEN
        RETURN;
    END IF;

    -- The enrollment contract decides whether this student can open the
    -- course content. Anonymous or non-enrolled students get previews only.
    IF p_student_id IS NULL THEN
        v_accessible := FALSE;
    ELSE
        SELECT COALESCE(ac.is_accessible, FALSE)
        INTO v_accessible
        FROM public.fn_student_course_access(p_student_id, p_course_id) ac;
    END IF;

    RETURN QUERY
    WITH syllabus AS (
        SELECT
            m.id          AS module_id,
            m.title       AS module_title,
            m.sequence_order AS module_order,
            l.id          AS lesson_id,
            l.title       AS lesson_title,
            l.sequence_order AS lesson_order,
            l.estimated_duration_minutes,
            l.is_preview
        FROM public.modules m
        JOIN public.lessons l ON l.module_id = m.id
        WHERE m.course_id = p_course_id
        UNION ALL
        SELECT
            NULL::BIGINT  AS module_id,
            NULL::VARCHAR AS module_title,
            0::INTEGER    AS module_order,
            l.id          AS lesson_id,
            l.title       AS lesson_title,
            l.sequence_order AS lesson_order,
            l.estimated_duration_minutes,
            l.is_preview
        FROM public.lessons l
        WHERE l.course_id = p_course_id
          AND l.module_id IS NULL
    )
    SELECT
        s.module_id,
        s.module_title,
        s.module_order,
        s.lesson_id,
        s.lesson_title,
        s.lesson_order,
        s.estimated_duration_minutes,
        s.is_preview,
        CASE
            WHEN s.is_preview THEN 'preview'
            WHEN v_accessible THEN 'available'
            ELSE 'locked'
        END::TEXT AS lesson_access_status,
        EXISTS (
            SELECT 1
            FROM public.enrollments e
            JOIN public.lesson_progress lp ON lp.enrollment_id = e.id
            WHERE e.user_id = p_student_id
              AND e.course_id = p_course_id
              AND lp.lesson_id = s.lesson_id
              AND lp.status = 'completed'
        ) AS lesson_passed
    FROM syllabus s
    ORDER BY s.module_order ASC, s.lesson_order ASC, s.lesson_id ASC;
END;
$$;