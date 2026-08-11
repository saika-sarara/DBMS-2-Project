-- =========================================================
-- trg_prevent_duplicate_enrollment
--
-- TRIGGER for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_prevent_duplicate_enrollment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.enrollments
        WHERE user_id = NEW.user_id
          AND course_id = NEW.course_id
          AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'LTN01: Student is already enrolled in course %.', NEW.course_id
            USING ERRCODE = 'LTN01';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_enrollment ON public.enrollments;

CREATE TRIGGER trg_prevent_duplicate_enrollment
BEFORE INSERT ON public.enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_prevent_duplicate_enrollment();
