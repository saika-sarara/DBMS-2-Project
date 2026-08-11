-- =========================================================
-- vw_public_course_cards
--
-- VIEW for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 3. Public course card view

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
