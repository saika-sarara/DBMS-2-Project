-- =========================================================
-- trg_lessons_set_updated_at
--
-- TRIGGER for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE TRIGGER trg_lessons_set_updated_at
BEFORE UPDATE ON public.lessons
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();
