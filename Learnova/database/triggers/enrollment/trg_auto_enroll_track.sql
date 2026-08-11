-- =========================================================
-- trg_auto_enroll_track
--
-- TRIGGER for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_auto_enroll_track()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM public.sp_enroll_student(NEW.user_id, tc.course_id, 'track')
    FROM public.track_courses tc
    JOIN public.courses c ON c.id = tc.course_id
    WHERE tc.track_id = NEW.track_id
      AND c.status = 'PUBLISHED';

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_enroll_track ON public.track_enrollments;

CREATE TRIGGER trg_auto_enroll_track
AFTER INSERT ON public.track_enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_auto_enroll_track();
