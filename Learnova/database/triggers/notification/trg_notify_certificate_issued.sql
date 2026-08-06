-- =========================================================
-- trg_notify_certificate_issued
--
-- TRIGGER for the notification feature.
-- Source of truth: notification.sql (V13). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_notify_certificate_issued()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_entity_title TEXT;
BEGIN
    IF NEW.type = 'course' THEN
        SELECT title INTO v_entity_title
        FROM public.courses WHERE id = NEW.course_id;
    ELSE
        SELECT title INTO v_entity_title
        FROM public.tracks WHERE id = NEW.track_id;
    END IF;

    PERFORM public.fn_create_notification(
        NEW.user_id,
        'Congratulations! Your certificate for "'
        || COALESCE(v_entity_title, 'your completed learning path')
        || '" has been issued.'
        || ' Verification code: ' || NEW.cert_code || '.',
        'certificate',
        NEW.id
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_certificate_issued ON public.certificates;

CREATE TRIGGER trg_notify_certificate_issued
AFTER INSERT ON public.certificates
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_certificate_issued();
