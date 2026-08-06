-- =========================================================
-- trg_unlock_first_lesson
--
-- TRIGGER for the progress feature.
-- Source of truth: progress.sql (V7). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_unlock_first_lesson()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_first_lesson_id BIGINT;
    v_allowed         BOOLEAN;
BEGIN
    -- The access decision is delegated to the prerequisite engine
    -- contract; the trigger does not calculate prerequisites itself.
    SELECT pe.allowed
    INTO v_allowed
    FROM public.fn_prerequisite_engine_course_access(NEW.user_id, NEW.course_id) pe;

    IF NOT COALESCE(v_allowed, FALSE) THEN
        RETURN NEW;
    END IF;

    v_first_lesson_id := public.fn_course_first_lesson_id(NEW.course_id);

    IF v_first_lesson_id IS NOT NULL THEN
        UPDATE public.lesson_progress
        SET status = 'unlocked',
            unlocked_at = COALESCE(unlocked_at, CURRENT_TIMESTAMP)
        WHERE enrollment_id = NEW.id
          AND lesson_id = v_first_lesson_id
          AND status = 'locked';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_unlock_first_lesson ON public.enrollments;

CREATE TRIGGER trg_unlock_first_lesson
AFTER INSERT ON public.enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_unlock_first_lesson();
