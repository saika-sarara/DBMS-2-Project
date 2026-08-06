-- =========================================================
-- fn_search_public_course_catalogue
--
-- FUNCTION for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 6. Public (non-personalized) catalogue search

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
