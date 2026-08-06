-- =========================================================
-- trg_auto_issue_certificate
--
-- TRIGGER for the certificate feature.
-- Source of truth: certificate.sql (V12). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_auto_issue_certificate_on_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM public.sp_issue_certificate(NEW.user_id, 'course', NEW.course_id);

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_issue_certificate ON public.enrollments;

CREATE TRIGGER trg_auto_issue_certificate
AFTER UPDATE OF status ON public.enrollments
FOR EACH ROW
WHEN (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed')
EXECUTE FUNCTION public.fn_auto_issue_certificate_on_completion();
