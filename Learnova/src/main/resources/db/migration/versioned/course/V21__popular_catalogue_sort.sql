-- =========================================================
-- V21: Popular catalogue sort
--
-- Adds a 'popular' sort option to both catalogue search
-- functions. 'popular' ranks by review volume first, then by
-- rating, which is intentionally distinct from 'rating'
-- (highest rating first, review count as tiebreaker).
--
-- The functions are recreated in place (CREATE OR REPLACE) so
-- the change is additive and the existing V5 checksum is
-- preserved for already-applied databases.
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
    course_id                  BIGINT,
    title                      VARCHAR,
    slug                       VARCHAR,
    short_description          VARCHAR,
    difficulty                 VARCHAR,
    thumbnail_url              TEXT,
    category_id                BIGINT,
    category_name              VARCHAR,
    avg_rating                 NUMERIC,
    review_count               INTEGER,
    total_lessons              INTEGER,
    estimated_duration_minutes INTEGER,
    instructor_id              BIGINT,
    instructor_name            TEXT,
    card_status                TEXT,
    is_locked                  BOOLEAN,
    is_enrolled                BOOLEAN,
    is_completed               BOOLEAN,
    lock_reason                TEXT,
    rank_score                 REAL,
    total_count                BIGINT
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
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'popular'
                THEN fc.review_count
        END DESC,
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'popular'
                THEN fc.avg_rating
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
            c.status = 'PUBLISHED'
            AND (
                c.category_id IS NULL
                OR cat.is_active = TRUE
            )
            AND (
                p_category_id IS NULL
                OR c.category_id = p_category_id
            )
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
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'relevance'
                 AND p_search IS NOT NULL
                 AND BTRIM(p_search) <> ''
                THEN fc.rank_score
        END DESC,
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'relevance'
                 AND (
                     p_search IS NULL
                     OR BTRIM(p_search) = ''
                 )
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
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'popular'
                THEN fc.review_count
        END DESC,
        CASE
            WHEN LOWER(COALESCE(p_sort, 'relevance')) = 'popular'
                THEN fc.avg_rating
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
