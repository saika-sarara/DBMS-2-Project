-- =========================================================
-- idx_content_blocks_lesson
--
-- INDEX for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX idx_content_blocks_lesson
    ON public.lesson_content_blocks (lesson_id);
