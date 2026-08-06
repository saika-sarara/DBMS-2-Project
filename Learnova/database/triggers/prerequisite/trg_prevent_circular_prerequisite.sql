-- =========================================================
-- trg_prevent_circular_prerequisite
--
-- TRIGGER for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_prevent_circular_prerequisite()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cycle BOOLEAN;
BEGIN
    IF NEW.course_id = NEW.prerequisite_course_id THEN
        RAISE EXCEPTION 'LTP02: A course cannot be its own prerequisite.'
            USING ERRCODE = 'LTP02';
    END IF;

    WITH RECURSIVE deps AS (
        SELECT cp.prerequisite_course_id
        FROM public.course_prerequisites cp
        WHERE cp.course_id = NEW.prerequisite_course_id
        UNION ALL
        SELECT cp.prerequisite_course_id
        FROM public.course_prerequisites cp
        JOIN deps d ON d.prerequisite_course_id = cp.course_id
    )
    SELECT EXISTS (SELECT 1 FROM deps WHERE prerequisite_course_id = NEW.course_id)
    INTO v_cycle;

    IF v_cycle THEN
        RAISE EXCEPTION 'LTP02: Adding this prerequisite would create a circular dependency.'
            USING ERRCODE = 'LTP02';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_circular_prerequisite ON public.course_prerequisites;

CREATE TRIGGER trg_prevent_circular_prerequisite
BEFORE INSERT OR UPDATE OF course_id, prerequisite_course_id
ON public.course_prerequisites
FOR EACH ROW
EXECUTE FUNCTION public.fn_prevent_circular_prerequisite();
