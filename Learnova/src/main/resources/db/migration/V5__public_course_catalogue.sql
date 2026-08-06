-- =========================================================
-- V5: Public course catalogue
--
-- All schema for the catalogue feature in one file:
--   * the catalogue trigger that maintains slug / search_vector /
--     published_at on every course write (created before any course
--     row is inserted by the V8 seed)
--   * the catalogue indexes
--   * the public course card view
--   * the anonymous-safe card status contract
--   * the personalized catalogue search (V9 fixed column order:
--     difficulty before thumbnail_url, matching the declared OUT
--     parameters exactly)
--   * the public (non-personalized) catalogue search
--   * course detail / syllabus / lesson-content reads
--
-- The courses table (with all catalogue columns and constraints)
-- is created by V4; this file adds the behaviour on top of it.
-- The course-authoring procedures are created by V4 as well, and
-- they rely on this trigger to keep slug / search_vector current.
-- =========================================================

-- =========================================================
-- 1. Catalogue fields trigger
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


-- =========================================================
-- 2. Catalogue indexes
-- =========================================================

-- Fast PostgreSQL full-text search.
CREATE INDEX idx_courses_search_vector
    ON public.courses
    USING GIN (search_vector);

-- Fast filtering of published courses.
CREATE INDEX idx_courses_public_catalogue
    ON public.courses (
        status,
        category_id,
        difficulty,
        published_at DESC
    );

-- Fast sorting by rating.
CREATE INDEX idx_courses_rating
    ON public.courses (
        avg_rating DESC,
        review_count DESC
    );


-- =========================================================
-- 3. Public course card view
-- =========================================================

CREATE OR REPLACE VIEW public.vw_public_course_cards AS
SELECT
    c.id                        AS course_id,
    c.title,
    c.slug,
    c.short_description,
    c.difficulty,
    c.thumbnail_url,
    c.category_id,
    cat.name                    AS category_name,
    c.avg_rating,
    c.review_count,
    c.total_lessons,
    c.estimated_duration_minutes,
    c.instructor_id,
    CONCAT_WS(' ', u.first_name, u.last_name) AS instructor_name,
    c.published_at
FROM public.courses c
LEFT JOIN public.categories cat ON cat.id = c.category_id
LEFT JOIN public.users u ON u.id = c.instructor_id
WHERE c.status = 'PUBLISHED'
  AND (c.category_id IS NULL OR cat.is_active = TRUE);


-- =========================================================
-- 4. Card status (personalized, anonymous-safe)
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_course_card_status(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    card_status TEXT,
    is_locked   BOOLEAN,
    is_enrolled BOOLEAN,
    is_completed BOOLEAN,
    lock_reason TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_status        VARCHAR(20);
    v_enr_status    VARCHAR(20);
    v_progress      NUMERIC(5,2);
    v_allowed       BOOLEAN;
    v_engine_reason TEXT;
BEGIN
    IF p_student_id IS NULL THEN
        card_status := 'login_required';
        is_locked := TRUE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := 'Log in to enroll in this course.';
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT c.status INTO v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        card_status := 'unavailable';
        is_locked := TRUE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := 'Course does not exist.';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_status <> 'PUBLISHED' THEN
        card_status := 'unavailable';
        is_locked := TRUE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := 'Course is not published.';
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT e.status, e.progress_pct
    INTO v_enr_status, v_progress
    FROM public.enrollments e
    WHERE e.user_id = p_student_id
      AND e.course_id = p_course_id;

    IF v_enr_status = 'completed' THEN
        card_status := 'completed';
        is_locked := FALSE;
        is_enrolled := TRUE;
        is_completed := TRUE;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_enr_status = 'active' THEN
        is_enrolled := TRUE;
        IF v_progress >= 100 THEN
            card_status := 'completed';
            is_completed := TRUE;
        ELSIF v_progress > 0 THEN
            card_status := 'continue';
        ELSE
            card_status := 'enrolled';
        END IF;
        is_locked := FALSE;
        RETURN NEXT;
        RETURN;
    END IF;

    -- Not enrolled: delegate the lock decision to the prerequisite engine
    -- CONTRACT. The course module never inspects the prerequisite graph.
    SELECT pe.allowed, pe.message
    INTO v_allowed, v_engine_reason
    FROM public.fn_prerequisite_engine_course_access(p_student_id, p_course_id) pe;

    IF COALESCE(v_allowed, FALSE) THEN
        card_status := 'available';
        is_locked := FALSE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := NULL;
    ELSE
        card_status := 'locked';
        is_locked := TRUE;
        is_enrolled := FALSE;
        is_completed := FALSE;
        lock_reason := COALESCE(
            NULLIF(v_engine_reason, ''),
            'This course is locked until all prerequisites are satisfied.'
        );
    END IF;

    RETURN NEXT;
    RETURN;
END;
$$;


-- =========================================================
-- 5. Personalized catalogue search
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_search_course_catalogue(
    p_student_id   BIGINT DEFAULT NULL,
    p_search       TEXT DEFAULT NULL,
    p_category_id  BIGINT DEFAULT NULL,
    p_difficulty   VARCHAR DEFAULT NULL,
    p_sort         VARCHAR DEFAULT 'relevance',
    p_limit        INTEGER DEFAULT 20,
    p_offset       INTEGER DEFAULT 0
)
RETURNS TABLE (
    course_id                 BIGINT,
    title                     VARCHAR,
    slug                      VARCHAR,
    short_description         VARCHAR,
    difficulty                VARCHAR,
    thumbnail_url             TEXT,
    category_id               BIGINT,
    category_name             VARCHAR,
    avg_rating                NUMERIC,
    review_count              INTEGER,
    total_lessons             INTEGER,
    estimated_duration_minutes INTEGER,
    instructor_id             BIGINT,
    instructor_name           TEXT,
    card_status               TEXT,
    is_locked                 BOOLEAN,
    is_enrolled               BOOLEAN,
    is_completed              BOOLEAN,
    lock_reason               TEXT,
    rank_score                REAL,
    total_count               BIGINT
)
LANGUAGE SQL
STABLE
AS $$
    WITH search_parameters AS (
        SELECT
            CASE
                WHEN p_search IS NULL OR BTRIM(p_search) = ''
                    THEN NULL
                ELSE WEBSEARCH_TO_TSQUERY('english', BTRIM(p_search))
            END AS search_query
    ),

    filtered_courses AS (
        SELECT
            c.id            AS course_id,
            c.title,
            c.slug,
            c.short_description,
            c.thumbnail_url,
            c.difficulty,
            c.category_id,
            COALESCE(cat.name, 'Uncategorized')::VARCHAR AS category_name,
            c.avg_rating,
            c.review_count,
            c.total_lessons,
            c.estimated_duration_minutes,
            c.instructor_id,
            CONCAT_WS(' ', u.first_name, u.last_name)::TEXT AS instructor_name,
            c.published_at,
            CASE
                WHEN sp.search_query IS NULL THEN 0.0::REAL
                ELSE TS_RANK_CD(c.search_vector, sp.search_query)::REAL
            END AS rank_score
        FROM public.courses c
        LEFT JOIN public.categories cat ON cat.id = c.category_id
        LEFT JOIN public.users u ON u.id = c.instructor_id
        CROSS JOIN search_parameters sp
        WHERE
            c.status = 'PUBLISHED'
            AND (c.category_id IS NULL OR cat.is_active = TRUE)
            AND (p_category_id IS NULL OR c.category_id = p_category_id)
            AND (
                p_difficulty IS NULL
                OR BTRIM(p_difficulty) = ''
                OR c.difficulty = UPPER(BTRIM(p_difficulty))
            )
            AND (
                sp.search_query IS NULL
                OR c.search_vector @@ sp.search_query
            )
    )

    SELECT
        fc.course_id,
        fc.title,
        fc.slug,
        fc.short_description,
        fc.difficulty,
        fc.thumbnail_url,
        fc.category_id,
        fc.category_name,
        fc.avg_rating,
        fc.review_count,
        fc.total_lessons,
        fc.estimated_duration_minutes,
        fc.instructor_id,
        fc.instructor_name,
        cs.card_status,
        cs.is_locked,
        cs.is_enrolled,
        cs.is_completed,
        cs.lock_reason,
        fc.rank_score,
        COUNT(*) OVER () AS total_count
    FROM filtered_courses fc
    CROSS JOIN LATERAL public.fn_course_card_status(p_student_id, fc.course_id) cs
    ORDER BY
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'relevance'
                 AND p_search IS NOT NULL AND BTRIM(p_search) <> ''
                THEN fc.rank_score
        END DESC,
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'relevance'
                 AND (p_search IS NULL OR BTRIM(p_search) = '')
                THEN fc.published_at
        END DESC NULLS LAST,
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'rating'
                THEN fc.avg_rating
        END DESC,
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'rating'
                THEN fc.review_count
        END DESC,
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'newest'
                THEN fc.published_at
        END DESC NULLS LAST,
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'title'
                THEN LOWER(fc.title)
        END ASC,
        fc.course_id ASC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50)
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;


-- =========================================================
-- 6. Public (non-personalized) catalogue search
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_search_public_course_catalogue(
    p_search       TEXT DEFAULT NULL,
    p_category_id  BIGINT DEFAULT NULL,
    p_difficulty   VARCHAR DEFAULT NULL,
    p_sort         VARCHAR DEFAULT 'relevance',
    p_limit        INTEGER DEFAULT 12,
    p_offset       INTEGER DEFAULT 0
)
RETURNS TABLE (
    course_id          BIGINT,
    title              VARCHAR,
    slug               VARCHAR,
    short_description  VARCHAR,
    thumbnail_url      TEXT,
    difficulty         VARCHAR,
    category_id        BIGINT,
    category_name      VARCHAR,
    avg_rating         NUMERIC,
    review_count       INTEGER,
    published_at       TIMESTAMPTZ,
    rank_score         REAL,
    total_count        BIGINT
)
LANGUAGE SQL
STABLE
AS $$
    WITH search_parameters AS (
        SELECT
            CASE
                WHEN p_search IS NULL
                     OR BTRIM(p_search) = ''
                    THEN NULL
                ELSE WEBSEARCH_TO_TSQUERY(
                    'english',
                    BTRIM(p_search)
                )
            END AS search_query
    ),

    filtered_courses AS (
        SELECT
            c.id AS course_id,
            c.title,
            c.slug,
            c.short_description,
            c.thumbnail_url,
            c.difficulty,
            c.category_id,

            COALESCE(
                cat.name,
                'Uncategorized'
            )::VARCHAR AS category_name,

            c.avg_rating,
            c.review_count,
            c.published_at,

            CASE
                WHEN sp.search_query IS NULL
                    THEN 0.0::REAL
                ELSE TS_RANK_CD(
                    c.search_vector,
                    sp.search_query
                )::REAL
            END AS rank_score

        FROM public.courses c

        LEFT JOIN public.categories cat
            ON cat.id = c.category_id

        CROSS JOIN search_parameters sp

        WHERE
            -- Public catalogue shows published courses only.
            c.status = 'PUBLISHED'

            -- Courses belonging to inactive categories are hidden.
            AND (
                c.category_id IS NULL
                OR cat.is_active = TRUE
            )

            -- Optional category filter.
            AND (
                p_category_id IS NULL
                OR c.category_id = p_category_id
            )

            -- Optional difficulty filter.
            AND (
                p_difficulty IS NULL
                OR BTRIM(p_difficulty) = ''
                OR c.difficulty = UPPER(BTRIM(p_difficulty))
            )

            -- Optional PostgreSQL full-text keyword search.
            AND (
                sp.search_query IS NULL
                OR c.search_vector @@ sp.search_query
            )
    )

    SELECT
        fc.course_id,
        fc.title,
        fc.slug,
        fc.short_description,
        fc.thumbnail_url,
        fc.difficulty,
        fc.category_id,
        fc.category_name,
        fc.avg_rating,
        fc.review_count,
        fc.published_at,
        fc.rank_score,

        COUNT(*) OVER () AS total_count

    FROM filtered_courses fc

    ORDER BY
        -- Search relevance when a keyword is present.
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'relevance'
                 AND p_search IS NOT NULL
                 AND BTRIM(p_search) <> ''
                THEN fc.rank_score
        END DESC,

        -- Without a search word, relevance sorting uses newest first.
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'relevance'
                 AND (
                     p_search IS NULL
                     OR BTRIM(p_search) = ''
                 )
                THEN fc.published_at
        END DESC NULLS LAST,

        -- Highest rating first.
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'rating'
                THEN fc.avg_rating
        END DESC,

        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'rating'
                THEN fc.review_count
        END DESC,

        -- Newest published course first.
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'newest'
                THEN fc.published_at
        END DESC NULLS LAST,

        -- Alphabetical title sorting.
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'title'
                THEN LOWER(fc.title)
        END ASC,

        -- Stable final ordering.
        fc.course_id ASC

    LIMIT
        LEAST(
            GREATEST(
                COALESCE(p_limit, 12),
                1
            ),
            50
        )

    OFFSET
        GREATEST(
            COALESCE(p_offset, 0),
            0
        );
$$;

COMMENT ON FUNCTION public.fn_search_public_course_catalogue(
    TEXT,
    BIGINT,
    VARCHAR,
    VARCHAR,
    INTEGER,
    INTEGER
)
IS
'Returns published courses with PostgreSQL full-text search, category and difficulty filtering, sorting, pagination and total count.';


-- =========================================================
-- 7. Course detail
-- =========================================================

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


-- =========================================================
-- 8. Syllabus (modules + ordered lessons)
-- =========================================================

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
    lesson_access_status  TEXT
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
        END::TEXT AS lesson_access_status
    FROM syllabus s
    ORDER BY s.module_order ASC, s.lesson_order ASC, s.lesson_id ASC;
END;
$$;


-- =========================================================
-- 9. Lesson content (preview or enrolled-only)
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_course_content_for_lesson(
    p_student_id BIGINT,
    p_lesson_id  BIGINT
)
RETURNS TABLE (
    block_id      BIGINT,
    lesson_id     BIGINT,
    block_type    VARCHAR,
    title         VARCHAR,
    body_markdown TEXT,
    resource_url  TEXT,
    sequence_order INTEGER
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_course_id  BIGINT;
    v_is_preview BOOLEAN;
    v_accessible BOOLEAN;
BEGIN
    SELECT l.course_id, l.is_preview
    INTO v_course_id, v_is_preview
    FROM public.lessons l
    WHERE l.id = p_lesson_id;

    IF v_course_id IS NULL THEN
        RAISE EXCEPTION 'LTC11: Lesson % does not exist.', p_lesson_id
            USING ERRCODE = 'LTC11';
    END IF;

    -- Preview lessons are available to everyone.
    IF v_is_preview THEN
        RETURN QUERY
        SELECT
            cb.id,
            cb.lesson_id,
            cb.block_type,
            cb.title,
            cb.body_markdown,
            cb.resource_url,
            cb.sequence_order
        FROM public.lesson_content_blocks cb
        WHERE cb.lesson_id = p_lesson_id
        ORDER BY cb.sequence_order ASC, cb.id ASC;
        RETURN;
    END IF;

    IF p_student_id IS NULL THEN
        RAISE EXCEPTION 'LTC12: Log in to view this lesson content.'
            USING ERRCODE = 'LTC12';
    END IF;

    SELECT COALESCE(ac.is_accessible, FALSE)
    INTO v_accessible
    FROM public.fn_student_course_access(p_student_id, v_course_id) ac;

    IF NOT v_accessible THEN
        RAISE EXCEPTION 'LTC12: You do not have access to this lesson. Enroll in the course first.'
            USING ERRCODE = 'LTC12';
    END IF;

    RETURN QUERY
    SELECT
        cb.id,
        cb.lesson_id,
        cb.block_type,
        cb.title,
        cb.body_markdown,
        cb.resource_url,
        cb.sequence_order
    FROM public.lesson_content_blocks cb
    WHERE cb.lesson_id = p_lesson_id
    ORDER BY cb.sequence_order ASC, cb.id ASC;
END;
$$;
