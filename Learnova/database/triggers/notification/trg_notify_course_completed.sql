-- =========================================================
-- trg_notify_course_completed
--
-- TRIGGER for the notification feature.
-- Source of truth: notification.sql (V13). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_notify_course_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_title TEXT;
BEGIN
    SELECT title INTO v_course_title
    FROM public.courses WHERE id = NEW.course_id;

    PERFORM public.fn_create_notification(
        NEW.user_id,
        'You completed the course "'
        || COALESCE(v_course_title, 'a course')
        || '". Your certificate is on the way!',
        'course',
        NEW.course_id
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_course_completed ON public.enrollments;

CREATE TRIGGER trg_notify_course_completed
AFTER UPDATE OF status ON public.enrollments
FOR EACH ROW
WHEN (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed')
EXECUTE FUNCTION public.fn_notify_course_completed();
