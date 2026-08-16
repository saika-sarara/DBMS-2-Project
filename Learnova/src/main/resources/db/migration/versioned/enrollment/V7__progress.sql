-- =========================================================
-- V7: Progress
--
-- All schema for the lesson-progress feature in one file:
--   * lesson_progress (per-enrollment per-lesson state)
--   * progress calculation functions
--   * the triggers that keep lesson_progress, enrollments and
--     track_enrollments in sync
--
-- The progress triggers fire against the enrollment schema
-- (enrollments / track_enrollments / lesson_progress); enrollment
-- is deployed by V6, which also owns the prerequisite engine
-- CONTRACT this module consults for unlock decisions.
-- =========================================================

-- =========================================================
-- 1. Lesson progress
-- =========================================================

CREATE TABLE public.lesson_progress (
    id            BIGSERIAL PRIMARY KEY,
    enrollment_id BIGINT NOT NULL REFERENCES public.enrollments (id) ON DELETE CASCADE,
    lesson_id     BIGINT NOT NULL REFERENCES public.lessons (id) ON DELETE CASCADE,
    status        VARCHAR(20) NOT NULL DEFAULT 'locked',
    unlocked_at   TIMESTAMPTZ,
    completed_at  TIMESTAMPTZ,

    CONSTRAINT uq_lesson_progress_enrollment_lesson
        UNIQUE (enrollment_id, lesson_id),

    CONSTRAINT chk_lesson_progress_status
        CHECK (status IN ('locked', 'unlocked', 'completed'))
);


-- =========================================================
-- 2. Progress calculation functions
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_course_first_lesson_id(p_course_id BIGINT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_first_lesson_id BIGINT;
BEGIN
    SELECT id
    INTO v_first_lesson_id
    FROM public.lessons
    WHERE course_id = p_course_id
    ORDER BY sequence_order ASC, id ASC
    LIMIT 1;

    RETURN v_first_lesson_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_calculate_course_progress(p_enrollment_id BIGINT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_lessons     INT;
    v_completed_lessons INT;
BEGIN
    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE lp.status = 'completed')
    INTO v_total_lessons, v_completed_lessons
    FROM public.lesson_progress lp
    WHERE lp.enrollment_id = p_enrollment_id;

    IF v_total_lessons = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND(
        (v_completed_lessons::NUMERIC / v_total_lessons::NUMERIC) * 100,
        2
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_calculate_track_progress(
    p_student_id BIGINT,
    p_track_id   BIGINT
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_courses INT;
    v_sum_progress  NUMERIC;
BEGIN
    SELECT COUNT(tc.course_id),
           COALESCE(SUM(e.progress_pct), 0)
    INTO v_total_courses, v_sum_progress
    FROM public.track_courses tc
    LEFT JOIN public.enrollments e
           ON e.course_id = tc.course_id
          AND e.user_id = p_student_id
    WHERE tc.track_id = p_track_id;

    IF v_total_courses = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND(v_sum_progress / v_total_courses, 2);
END;
$$;


-- =========================================================
-- 3. Progress triggers
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_initialize_lesson_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.lesson_progress (enrollment_id, lesson_id, status)
    SELECT NEW.id, l.id, 'locked'
    FROM public.lessons l
    WHERE l.course_id = NEW.course_id
    ON CONFLICT (enrollment_id, lesson_id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_initialize_lesson_progress ON public.enrollments;
CREATE TRIGGER trg_initialize_lesson_progress
AFTER INSERT ON public.enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_initialize_lesson_progress();

CREATE OR REPLACE FUNCTION public.fn_unlock_first_lesson()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_first_lesson_id BIGINT;
    v_allowed         BOOLEAN;
BEGIN
    -- The access decision is delegated to the prerequisite engine
    -- contract; the trigger does not calculate prerequisites itself.
    SELECT pe.allowed
    INTO v_allowed
    FROM public.fn_prerequisite_engine_course_access(NEW.user_id, NEW.course_id) pe;

    IF NOT COALESCE(v_allowed, FALSE) THEN
        RETURN NEW;
    END IF;

    v_first_lesson_id := public.fn_course_first_lesson_id(NEW.course_id);

    IF v_first_lesson_id IS NOT NULL THEN
        UPDATE public.lesson_progress
        SET status = 'unlocked',
            unlocked_at = COALESCE(unlocked_at, CURRENT_TIMESTAMP)
        WHERE enrollment_id = NEW.id
          AND lesson_id = v_first_lesson_id
          AND status = 'locked';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_unlock_first_lesson ON public.enrollments;
CREATE TRIGGER trg_unlock_first_lesson
AFTER INSERT ON public.enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_unlock_first_lesson();

CREATE OR REPLACE FUNCTION public.fn_unlock_track_courses_after_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.lesson_progress lp
    SET status = 'unlocked',
        unlocked_at = COALESCE(lp.unlocked_at, CURRENT_TIMESTAMP)
    FROM public.enrollments e
    WHERE lp.enrollment_id = e.id
      AND e.user_id = NEW.user_id
      AND e.status = 'active'
      AND EXISTS (
          SELECT 1
          FROM public.fn_prerequisite_engine_course_access(NEW.user_id, e.course_id) pe
          WHERE pe.allowed
      )
      AND lp.lesson_id = public.fn_course_first_lesson_id(e.course_id)
      AND lp.status = 'locked';

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_unlock_track_courses_after_completion ON public.enrollments;
CREATE TRIGGER trg_unlock_track_courses_after_completion
AFTER UPDATE OF status ON public.enrollments
FOR EACH ROW
WHEN (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed')
EXECUTE FUNCTION public.fn_unlock_track_courses_after_completion();

CREATE OR REPLACE FUNCTION public.fn_update_course_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_enrollment_id BIGINT;
    v_progress      NUMERIC(5,2);
    v_status        VARCHAR(20);
BEGIN
    v_enrollment_id := COALESCE(NEW.enrollment_id, OLD.enrollment_id);

    v_progress := public.fn_calculate_course_progress(v_enrollment_id);

    SELECT status
    INTO v_status
    FROM public.enrollments
    WHERE id = v_enrollment_id;

    IF v_status = 'active' AND v_progress >= 100 THEN
        UPDATE public.enrollments
        SET progress_pct = v_progress,
            status = 'completed',
            completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP)
        WHERE id = v_enrollment_id;
    ELSIF v_status = 'active' OR v_progress < 100 THEN
        UPDATE public.enrollments
        SET progress_pct = v_progress
        WHERE id = v_enrollment_id
          AND progress_pct <> v_progress;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_update_course_progress ON public.lesson_progress;
CREATE TRIGGER trg_update_course_progress
AFTER INSERT OR UPDATE OF status OR DELETE ON public.lesson_progress
FOR EACH ROW
EXECUTE FUNCTION public.fn_update_course_progress();

CREATE OR REPLACE FUNCTION public.fn_update_track_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.track_enrollments te
    SET progress_pct = cp.new_progress,
        status = CASE
                    WHEN cp.new_progress >= 100 AND te.status = 'active' THEN 'completed'
                    ELSE te.status
                 END,
        completed_at = CASE
                    WHEN cp.new_progress >= 100 AND te.status = 'active'
                         THEN COALESCE(te.completed_at, CURRENT_TIMESTAMP)
                    ELSE te.completed_at
                 END
    FROM (
        SELECT te2.id AS track_enrollment_id,
               public.fn_calculate_track_progress(NEW.user_id, te2.track_id) AS new_progress
        FROM public.track_enrollments te2
        WHERE te2.user_id = NEW.user_id
          AND EXISTS (
              SELECT 1
              FROM public.track_courses tc2
              WHERE tc2.track_id = te2.track_id
                AND tc2.course_id = NEW.course_id
          )
    ) cp
    WHERE te.id = cp.track_enrollment_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_track_progress ON public.enrollments;
CREATE TRIGGER trg_update_track_progress
AFTER INSERT OR UPDATE OF progress_pct, status ON public.enrollments
FOR EACH ROW
EXECUTE FUNCTION public.fn_update_track_progress();


-- =========================================================
-- 4. Progress indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_lesson_progress_enrollment_status
    ON public.lesson_progress (enrollment_id, status);
