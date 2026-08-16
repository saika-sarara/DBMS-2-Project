-- =========================================================
-- V26: Course enrollment automatically joins its Track
--
-- Required rule (spec): when a Student enrolls in the FIRST course of a
-- published Track, the system automatically creates the Track enrollment.
-- The existing V6 trg_auto_enroll_track then fires on that Track
-- enrollment and enrolls the Student in every published course of the
-- Track (source = 'track', so prerequisites are not re-enforced at
-- enrollment time — the lesson-unlock triggers gate progress instead).
--
-- Previously the only path into a Track was sp_enroll_track / the UI; a
-- standalone course enrollment never joined its Track. This migration adds
-- the missing COURSE -> TRACK direction (the TRACK -> COURSES direction
-- already exists in V6).
--
-- Safety:
--   * guarded to standalone enrollments, so the nested 'track' inserts
--     fired by fn_auto_enroll_track do not recurse
--   * ON CONFLICT DO NOTHING on track_enrollments (uq_track_enrollments_user_track)
--   * only tracks with status = 'PUBLISHED' are joined
--   * "first course in a track" = the track_courses row with the lowest
--     sequence_order (the ordering contract, same as lessons)
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_auto_join_track_on_course_enrollment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_track_id BIGINT;
BEGIN
    -- Only a direct/standalone enrollment starts the flow. 'track' inserts
    -- created by fn_auto_enroll_track must not re-trigger it.
    IF NEW.source <> 'standalone' THEN
        RETURN NEW;
    END IF;

    FOR v_track_id IN
        SELECT tc.track_id
        FROM public.track_courses tc
        JOIN public.tracks t ON t.id = tc.track_id AND t.status = 'PUBLISHED'
        WHERE tc.course_id = NEW.course_id
          AND tc.sequence_order = (
              SELECT MIN(tc2.sequence_order)
              FROM public.track_courses tc2
              WHERE tc2.track_id = tc.track_id
          )
    LOOP
        INSERT INTO public.track_enrollments (user_id, track_id)
        VALUES (NEW.user_id, v_track_id)
        ON CONFLICT (user_id, track_id) DO NOTHING;
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_join_track_on_course_enrollment ON public.enrollments;
CREATE TRIGGER trg_auto_join_track_on_course_enrollment
AFTER INSERT ON public.enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_auto_join_track_on_course_enrollment();
