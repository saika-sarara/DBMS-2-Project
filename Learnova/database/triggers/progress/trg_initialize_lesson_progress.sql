-- =========================================================
-- trg_initialize_lesson_progress
--
-- TRIGGER for the progress feature.
-- Source of truth: progress.sql (V7). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_initialize_lesson_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.lesson_progress (enrollment_id, lesson_id, status)
    SELECT NEW.id, l.id, 'locked'
    FROM public.lessons l
    WHERE l.course_id = NEW.course_id
    ON CONFLICT (enrollment_id, lesson_id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_initialize_lesson_progress ON public.enrollments;

CREATE TRIGGER trg_initialize_lesson_progress
AFTER INSERT ON public.enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_initialize_lesson_progress();
