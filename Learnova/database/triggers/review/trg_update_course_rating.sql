-- =========================================================
-- trg_update_course_rating
--
-- TRIGGER for the review feature.
-- Source of truth: review.sql (V11). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_update_course_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
BEGIN
    v_course_id := COALESCE(NEW.course_id, OLD.course_id);

    IF v_course_id IS NOT NULL THEN
        UPDATE public.courses
        SET avg_rating = (
                SELECT COALESCE(ROUND(AVG(rating), 2), 0.00)
                FROM public.reviews
                WHERE course_id = v_course_id
            ),
            review_count = (
                SELECT COUNT(*)
                FROM public.reviews
                WHERE course_id = v_course_id
            )
        WHERE id = v_course_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_update_course_rating ON public.reviews;

CREATE TRIGGER trg_update_course_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.fn_update_course_rating();
