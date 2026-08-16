-- ============================================================
-- Learnova
-- Current automatic Track enrollment trigger
--
-- Historical implementation exists in V26.
-- This repeatable migration owns the CURRENT trigger
-- definition.
-- ============================================================


CREATE OR REPLACE FUNCTION public.fn_auto_join_track_on_course_enrollment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_track_id BIGINT;
BEGIN

    /*
     * Track-generated course enrollments must not recursively
     * create another Track enrollment.
     */
    IF NEW.source <> 'standalone' THEN
        RETURN NEW;
    END IF;


    /*
     * A standalone enrollment automatically joins every
     * published Track for which the enrolled course is the
     * first course in sequence.
     */
    FOR v_track_id IN

        SELECT tc.track_id

        FROM public.track_courses tc

        JOIN public.tracks t
          ON t.id = tc.track_id

        WHERE tc.course_id = NEW.course_id

          AND t.status = 'PUBLISHED'

          AND tc.sequence_order = (
              SELECT MIN(tc_first.sequence_order)

              FROM public.track_courses tc_first

              WHERE tc_first.track_id =
                    tc.track_id
          )

    LOOP

        INSERT INTO public.track_enrollments (
            user_id,
            track_id
        )
        VALUES (
            NEW.user_id,
            v_track_id
        )

        ON CONFLICT (
            user_id,
            track_id
        )
        DO NOTHING;

    END LOOP;


    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS
    trg_auto_join_track_on_course_enrollment
ON public.enrollments;


CREATE TRIGGER
    trg_auto_join_track_on_course_enrollment

AFTER INSERT
ON public.enrollments

FOR EACH ROW

EXECUTE FUNCTION
    public.fn_auto_join_track_on_course_enrollment();
