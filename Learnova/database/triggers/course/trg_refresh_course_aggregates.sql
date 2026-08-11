-- =========================================================
-- trg_refresh_course_aggregates
--
-- TRIGGER for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_refresh_course_aggregates()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_id BIGINT;
BEGIN
    v_course_id := COALESCE(NEW.course_id, OLD.course_id);

    IF v_course_id IS NOT NULL THEN
        PERFORM public.fn_update_course_aggregate_counts(v_course_id);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_refresh_course_aggregates ON public.lessons;

CREATE TRIGGER trg_refresh_course_aggregates
AFTER INSERT OR UPDATE OF estimated_duration_minutes OR DELETE ON public.lessons
FOR EACH ROW
EXECUTE FUNCTION public.fn_refresh_course_aggregates();
