-- Track membership must not make locked courses appear accessible. Keep the
-- existing prerequisite engine as the single decision-maker: a track enrolls
-- only courses that it currently permits, then advances as completions make
-- later courses eligible.

CREATE OR REPLACE FUNCTION public.fn_auto_enroll_track()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM public.sp_enroll_student(NEW.user_id, tc.course_id, 'track')
    FROM public.track_courses tc
    JOIN public.courses c ON c.id = tc.course_id
    WHERE tc.track_id = NEW.track_id
      AND c.status = 'PUBLISHED'
      AND EXISTS (
          SELECT 1
          FROM public.fn_prerequisite_engine_course_access(
              NEW.user_id,
              tc.course_id
          ) access
          WHERE access.allowed
      );

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_unlock_track_courses_after_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Add every newly eligible course from the student's joined tracks. The
    -- prerequisite function continues to govern score and bypass semantics.
    PERFORM public.sp_enroll_student(NEW.user_id, tc.course_id, 'track')
    FROM public.track_enrollments te
    JOIN public.track_courses tc ON tc.track_id = te.track_id
    JOIN public.courses c ON c.id = tc.course_id
    WHERE te.user_id = NEW.user_id
      AND c.status = 'PUBLISHED'
      AND NOT EXISTS (
          SELECT 1
          FROM public.enrollments e
          WHERE e.user_id = NEW.user_id
            AND e.course_id = tc.course_id
      )
      AND EXISTS (
          SELECT 1
          FROM public.fn_prerequisite_engine_course_access(
              NEW.user_id,
              tc.course_id
          ) access
          WHERE access.allowed
      );

    -- Preserve the existing behavior for historical track enrollments that
    -- were created before this migration: unlock their first lesson once the
    -- prerequisite engine permits access.
    UPDATE public.lesson_progress lp
    SET status = 'unlocked',
        unlocked_at = COALESCE(lp.unlocked_at, CURRENT_TIMESTAMP)
    FROM public.enrollments e
    WHERE lp.enrollment_id = e.id
      AND e.user_id = NEW.user_id
      AND e.status = 'active'
      AND EXISTS (
          SELECT 1
          FROM public.fn_prerequisite_engine_course_access(NEW.user_id, e.course_id) access
          WHERE access.allowed
      )
      AND lp.lesson_id = public.fn_course_first_lesson_id(e.course_id)
      AND lp.status = 'locked';

    RETURN NEW;
END;
$$;
