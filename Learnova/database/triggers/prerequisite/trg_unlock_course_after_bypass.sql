-- =========================================================
-- trg_unlock_course_after_bypass
--
-- TRIGGER for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_unlock_course_after_bypass()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.lesson_progress lp
    SET status = 'unlocked',
        unlocked_at = COALESCE(lp.unlocked_at, CURRENT_TIMESTAMP)
    FROM public.enrollments e
    WHERE lp.enrollment_id = e.id
      AND e.user_id = NEW.user_id
      AND e.status = 'active'
      AND EXISTS (
          SELECT 1
          FROM public.fn_prerequisite_engine_course_access(NEW.user_id, e.course_id) pe
          WHERE pe.allowed
      )
      AND lp.lesson_id = public.fn_course_first_lesson_id(e.course_id)
      AND lp.status = 'locked';

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_unlock_course_after_bypass ON public.course_bypasses;

CREATE TRIGGER trg_unlock_course_after_bypass
AFTER INSERT ON public.course_bypasses
FOR EACH ROW
EXECUTE FUNCTION public.fn_unlock_course_after_bypass();
