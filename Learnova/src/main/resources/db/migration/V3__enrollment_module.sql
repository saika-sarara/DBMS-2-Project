-- =========================================================
-- V3: Enrollment module
--
-- Deploys the enrollment module on top of the V2 auth schema.
--
--  * Defines the CROSS-MODULE COURSE CONTRACT that later modules
--    (course, prerequisite, quiz, progress, ...) build on. These
--    are the minimal tables the enrollment procedures depend on:
--      courses(id, title, status), lessons(id, course_id, title,
--      sequence_order), tracks(id, title, status),
--      track_courses(track_id, course_id, sequence_order).
--  * Adds the enrollment star/ops layer: enrollments,
--    track_enrollments, lesson_progress.
--  * Adds the fresh admin counters fn_admin_enrollment_stats().
--  * PREREQUISITE OWNERSHIP: enrollment does NOT own the prerequisite
--    graph. The course_prerequisites / course_bypasses tables, the
--    recursive closure view (vw_course_prerequisite_closure), the
--    bypass trigger and the fn_prerequisite_satisfied /
--    fn_check_prerequisites_met / fn_find_blocking_course helpers all
--    belong to the PREREQUISITE MODULE and are NOT defined here.
--    Enrollment depends only on the prerequisite engine CONTRACT
--    fn_prerequisite_engine_course_access(...), provided below as a
--    temporary placeholder that the prerequisite module replaces.
--  * ALL enrollment business rules and exception handling live in
--    the database (procedures raise LTxxx error codes; unexpected
--    errors are reported to the server log and re-raised as LT500).
--
-- Idempotency note: Flyway runs each migration once per database,
-- so plain CREATE statements are used. Mirrors the files under
-- database/schema, database/functions, database/procedures,
-- database/triggers and database/views which are the readable
-- design source of truth.
-- =========================================================

-- =========================================================
-- 1. Course contract (cross-module)
-- =========================================================

CREATE TABLE public.courses (
    id          BIGSERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_courses_status
        CHECK (status IN ('DRAFT', 'PENDING', 'PUBLISHED'))
);

CREATE TABLE public.lessons (
    id             BIGSERIAL PRIMARY KEY,
    course_id      BIGINT NOT NULL REFERENCES public.courses (id) ON DELETE CASCADE,
    title          VARCHAR(255) NOT NULL,
    sequence_order INT NOT NULL DEFAULT 0,

    CONSTRAINT uq_lessons_course_sequence
        UNIQUE (course_id, sequence_order)
);

CREATE TABLE public.tracks (
    id          BIGSERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_tracks_status
        CHECK (status IN ('DRAFT', 'PENDING', 'PUBLISHED'))
);

CREATE TABLE public.track_courses (
    track_id       BIGINT NOT NULL REFERENCES public.tracks (id) ON DELETE CASCADE,
    course_id      BIGINT NOT NULL REFERENCES public.courses (id) ON DELETE CASCADE,
    sequence_order INT NOT NULL DEFAULT 0,

    CONSTRAINT pk_track_courses
        PRIMARY KEY (track_id, course_id)
);

-- NOTE: course_prerequisites and course_bypasses are NOT defined here.
-- They belong to the prerequisite module and are owned by it; enrollment
-- only talks to the prerequisite engine contract (see section 3).

-- =========================================================
-- 2. Enrollment schema
-- =========================================================

CREATE TABLE public.enrollments (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    course_id       BIGINT NOT NULL REFERENCES public.courses (id) ON DELETE CASCADE,
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
    progress_pct    NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    final_score_pct NUMERIC(5,2),
    source          VARCHAR(20) NOT NULL DEFAULT 'standalone',
    enrolled_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at    TIMESTAMPTZ,

    CONSTRAINT uq_enrollments_user_course
        UNIQUE (user_id, course_id),

    CONSTRAINT chk_enrollments_status
        CHECK (status IN ('active', 'completed')),

    CONSTRAINT chk_enrollments_source
        CHECK (source IN ('standalone', 'track')),

    CONSTRAINT chk_enrollments_progress_range
        CHECK (progress_pct >= 0 AND progress_pct <= 100)
);

CREATE TABLE public.track_enrollments (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    track_id     BIGINT NOT NULL REFERENCES public.tracks (id) ON DELETE CASCADE,
    status       VARCHAR(20) NOT NULL DEFAULT 'active',
    progress_pct NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    enrolled_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,

    CONSTRAINT uq_track_enrollments_user_track
        UNIQUE (user_id, track_id),

    CONSTRAINT chk_track_enrollments_status
        CHECK (status IN ('active', 'completed')),

    CONSTRAINT chk_track_enrollments_progress_range
        CHECK (progress_pct >= 0 AND progress_pct <= 100)
);

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
-- 3. Enrollment functions
-- =========================================================

-- =========================================================
-- 3.0 Prerequisite engine contract (EXTERNAL DEPENDENCY)
--
-- OWNED BY THE PREREQUISITE MODULE, NOT by enrollment.
-- sp_enroll_student, fn_student_course_access and the unlock
-- triggers treat this function as their ONLY entry point into
-- prerequisite decisions. This placeholder returns "allowed" so the
-- enrollment module keeps working while the prerequisite engine is
-- not connected. The prerequisite module must replace only the BODY
-- (never the signature) when it deploys.
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_prerequisite_engine_course_access(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    allowed            BOOLEAN,
    reason_code        TEXT,
    message            TEXT,
    blocking_course_id BIGINT
)
LANGUAGE sql
AS $$
    SELECT
        TRUE                                AS allowed,
        'PREREQ_ENGINE_PENDING'::TEXT       AS reason_code,
        'Prerequisite engine module is not connected yet.'::TEXT AS message,
        NULL::BIGINT                        AS blocking_course_id;
$$;

CREATE OR REPLACE FUNCTION public.fn_user_is_active_student(p_user_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_active  BOOLEAN;
    v_is_student BOOLEAN;
BEGIN
    SELECT account_status = 'ACTIVE'
    INTO v_is_active
    FROM public.users
    WHERE id = p_user_id;

    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = p_user_id
          AND r.name = 'STUDENT'
    )
    INTO v_is_student;

    RETURN COALESCE(v_is_active, FALSE) AND v_is_student;
END;
$$;

-- NOTE: fn_prerequisite_satisfied, fn_check_prerequisites_met and
-- fn_find_blocking_course are NOT defined here. They belong to the
-- prerequisite module; enrollment only consumes the engine contract
-- defined in section 3.0.

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

CREATE OR REPLACE FUNCTION public.fn_student_course_access(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    is_accessible         BOOLEAN,
    reason_code           TEXT,
    reason                TEXT,
    enrollment_status     TEXT,
    progress_pct          NUMERIC(5,2),
    blocking_course_id    BIGINT,
    blocking_course_title TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_title       TEXT;
    v_course_status      VARCHAR(20);
    v_enrollment_status  VARCHAR(20);
    v_progress           NUMERIC(5,2);
    v_allowed            BOOLEAN;
    v_engine_reason_code TEXT;
    v_engine_message     TEXT;
    v_engine_blocking    BIGINT;
BEGIN
    SELECT c.title, c.status
    INTO v_course_title, v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_course_title IS NULL THEN
        is_accessible := FALSE;
        reason_code := 'course_not_found';
        reason := 'Course does not exist.';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_course_status <> 'PUBLISHED' THEN
        is_accessible := FALSE;
        reason_code := 'course_not_published';
        reason := 'Course is not published.';
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT e.status, e.progress_pct
    INTO v_enrollment_status, v_progress
    FROM public.enrollments e
    WHERE e.user_id = p_student_id
      AND e.course_id = p_course_id;

    IF v_enrollment_status IS NULL THEN
        is_accessible := FALSE;
        reason_code := 'not_enrolled';
        reason := 'Student is not enrolled in this course.';
        RETURN NEXT;
        RETURN;
    END IF;

    enrollment_status := v_enrollment_status;
    progress_pct := v_progress;

    IF v_enrollment_status = 'completed' THEN
        is_accessible := TRUE;
        reason_code := 'completed';
        reason := 'Course already completed.';
        RETURN NEXT;
        RETURN;
    END IF;

    -- The prerequisite decision is DELEGATED to the prerequisite
    -- engine contract. Enrollment does not inspect the prerequisite
    -- graph or bypass records itself.
    SELECT pe.allowed, pe.reason_code, pe.message, pe.blocking_course_id
    INTO v_allowed, v_engine_reason_code, v_engine_message, v_engine_blocking
    FROM public.fn_prerequisite_engine_course_access(p_student_id, p_course_id) pe;

    IF COALESCE(v_allowed, FALSE) THEN
        is_accessible := TRUE;
        reason_code := 'active';
        reason := 'Course is accessible.';
        RETURN NEXT;
        RETURN;
    END IF;

    is_accessible := FALSE;
    reason_code := 'prerequisites_locked';
    reason := COALESCE(NULLIF(v_engine_message, ''), 'Course is locked until all prerequisites are satisfied.');
    blocking_course_id := v_engine_blocking;

    -- Resolve the title only for display; the blocking decision came
    -- from the prerequisite engine.
    SELECT title
    INTO blocking_course_title
    FROM public.courses
    WHERE id = v_engine_blocking;

    RETURN NEXT;
    RETURN;
END;
$$;

-- =========================================================
-- 4. Enrollment procedures (returning functions)
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_enroll_student(
    p_student_id BIGINT,
    p_course_id  BIGINT,
    p_source     TEXT DEFAULT 'standalone'
)
RETURNS TABLE (
    enrollment_id    BIGINT,
    entity_id        BIGINT,
    entity_title     TEXT,
    status           VARCHAR(20),
    progress_pct     NUMERIC(5,2),
    source           VARCHAR(20),
    enrolled_at      TIMESTAMPTZ,
    already_enrolled BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_title       TEXT;
    v_course_status      VARCHAR(20);
    v_normalized_source  VARCHAR(20);
    v_allowed            BOOLEAN;
    v_engine_reason_code TEXT;
    v_engine_message     TEXT;
    v_engine_blocking    BIGINT;
BEGIN
    IF NOT public.fn_user_is_active_student(p_student_id) THEN
        RAISE EXCEPTION 'LTU01: Only active students can enroll in courses.'
            USING ERRCODE = 'LTU01';
    END IF;

    SELECT c.title, c.status
    INTO v_course_title, v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_course_title IS NULL THEN
        RAISE EXCEPTION 'LTC01: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC01';
    END IF;

    IF v_course_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'LTC01: Course % is not published.', p_course_id
            USING ERRCODE = 'LTC01';
    END IF;

    v_normalized_source := LOWER(COALESCE(p_source, 'standalone'));
    IF v_normalized_source NOT IN ('standalone', 'track') THEN
        v_normalized_source := 'standalone';
    END IF;

    SELECT e.id, e.status, e.progress_pct, e.source, e.enrolled_at
    INTO enrollment_id, status, progress_pct, source, enrolled_at
    FROM public.enrollments e
    WHERE e.user_id = p_student_id
      AND e.course_id = p_course_id;

    IF enrollment_id IS NOT NULL THEN
        entity_id := p_course_id;
        entity_title := v_course_title;
        already_enrolled := TRUE;

        IF v_normalized_source = 'standalone' THEN
            IF status = 'active' THEN
                RAISE EXCEPTION 'LTN01: Student is already enrolled in course %.', p_course_id
                    USING ERRCODE = 'LTN01';
            END IF;
            RAISE EXCEPTION 'LTC02: Course % was already completed and cannot be re-enrolled.', p_course_id
                USING ERRCODE = 'LTC02';
        END IF;

        RETURN NEXT;
        RETURN;
    END IF;

    -- Standalone enrollments verify course eligibility through the
    -- prerequisite engine CONTRACT. Enrollment owns no prerequisite
    -- calculation; the engine decides and returns the message.
    IF v_normalized_source = 'standalone' THEN
        SELECT pe.allowed, pe.reason_code, pe.message, pe.blocking_course_id
        INTO v_allowed, v_engine_reason_code, v_engine_message, v_engine_blocking
        FROM public.fn_prerequisite_engine_course_access(p_student_id, p_course_id) pe;

        IF NOT COALESCE(v_allowed, FALSE) THEN
            RAISE EXCEPTION 'LTP01: %',
                COALESCE(NULLIF(v_engine_message, ''), 'Prerequisites for course ' || p_course_id || ' are not satisfied.')
                USING ERRCODE = 'LTP01';
        END IF;
    END IF;

    INSERT INTO public.enrollments (user_id, course_id, source)
    VALUES (p_student_id, p_course_id, v_normalized_source)
    RETURNING public.enrollments.id,
              public.enrollments.status,
              public.enrollments.progress_pct,
              public.enrollments.source,
              public.enrollments.enrolled_at
    INTO enrollment_id, status, progress_pct, source, enrolled_at;

    entity_id := p_course_id;
    entity_title := v_course_title;
    already_enrolled := FALSE;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTU01', 'LTC01', 'LTT01', 'LTN01', 'LTN02', 'LTC02', 'LTP01') THEN
            RAISE;
        END IF;

        -- Reported to the server log (a table insert here could not persist:
        -- the exception block's subtransaction is rolled back when the error
        -- propagates, and there are no autonomous transactions).
        RAISE LOG 'sp_enroll_student unexpected error sqlstate=%: %', SQLSTATE, SQLERRM;

        RAISE EXCEPTION 'LT500: Unexpected database error while enrolling: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_enroll_track(
    p_student_id BIGINT,
    p_track_id   BIGINT
)
RETURNS TABLE (
    track_enrollment_id BIGINT,
    entity_id           BIGINT,
    entity_title        TEXT,
    status              VARCHAR(20),
    progress_pct        NUMERIC(5,2),
    source              VARCHAR(20),
    enrolled_at         TIMESTAMPTZ,
    already_enrolled    BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_track_title  TEXT;
    v_track_status VARCHAR(20);
BEGIN
    IF NOT public.fn_user_is_active_student(p_student_id) THEN
        RAISE EXCEPTION 'LTU01: Only active students can enroll in tracks.'
            USING ERRCODE = 'LTU01';
    END IF;

    SELECT t.title, t.status
    INTO v_track_title, v_track_status
    FROM public.tracks t
    WHERE t.id = p_track_id;

    IF v_track_title IS NULL THEN
        RAISE EXCEPTION 'LTT01: Track % does not exist.', p_track_id
            USING ERRCODE = 'LTT01';
    END IF;

    IF v_track_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'LTT01: Track % is not published.', p_track_id
            USING ERRCODE = 'LTT01';
    END IF;

    SELECT te.id, te.status, te.progress_pct, te.enrolled_at
    INTO track_enrollment_id, status, progress_pct, enrolled_at
    FROM public.track_enrollments te
    WHERE te.user_id = p_student_id
      AND te.track_id = p_track_id;

    IF track_enrollment_id IS NOT NULL THEN
        RAISE EXCEPTION 'LTN02: Student is already enrolled in track %.', p_track_id
            USING ERRCODE = 'LTN02';
    END IF;

    INSERT INTO public.track_enrollments (user_id, track_id)
    VALUES (p_student_id, p_track_id)
    RETURNING public.track_enrollments.id,
              public.track_enrollments.status,
              public.track_enrollments.progress_pct,
              public.track_enrollments.enrolled_at
    INTO track_enrollment_id, status, progress_pct, enrolled_at;

    entity_id := p_track_id;
    entity_title := v_track_title;
    source := 'track';
    already_enrolled := FALSE;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTU01', 'LTC01', 'LTT01', 'LTN01', 'LTN02', 'LTC02', 'LTP01') THEN
            RAISE;
        END IF;

        RAISE LOG 'sp_enroll_track unexpected error sqlstate=%: %', SQLSTATE, SQLERRM;

        RAISE EXCEPTION 'LT500: Unexpected database error while enrolling: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

-- =========================================================
-- 5. Enrollment triggers
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

-- NOTE: trg_unlock_course_after_bypass is NOT defined here. It reacts to
-- the course_bypasses table, which belongs to the prerequisite module;
-- that module owns the trigger.

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
-- 6. Enrollment indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_enrollments_user_status
    ON public.enrollments (user_id, status);

CREATE INDEX IF NOT EXISTS idx_lesson_progress_enrollment_status
    ON public.lesson_progress (enrollment_id, status);

CREATE INDEX IF NOT EXISTS idx_track_enrollments_user_status
    ON public.track_enrollments (user_id, status);

-- =========================================================
-- 7. Reporting
-- =========================================================

-- NOTE: vw_course_prerequisite_closure is NOT defined here. It is a
-- recursive-CTE view over the prerequisite module's course_prerequisites
-- table and belongs to that module.

CREATE OR REPLACE FUNCTION public.fn_admin_enrollment_stats()
RETURNS TABLE (
    total_users           BIGINT,
    active_students       BIGINT,
    total_courses         BIGINT,
    published_courses     BIGINT,
    total_enrollments     BIGINT,
    active_enrollments    BIGINT,
    completed_enrollments BIGINT,
    distinct_students     BIGINT
)
LANGUAGE sql
AS $$
    SELECT
        (SELECT COUNT(*) FROM public.users),
        (SELECT COUNT(DISTINCT u.id)
           FROM public.users u
           JOIN public.user_roles ur ON ur.user_id = u.id
           JOIN public.roles r ON r.id = ur.role_id
          WHERE u.account_status = 'ACTIVE'
            AND r.name = 'STUDENT'),
        (SELECT COUNT(*) FROM public.courses),
        (SELECT COUNT(*) FROM public.courses WHERE status = 'PUBLISHED'),
        (SELECT COUNT(*) FROM public.enrollments),
        (SELECT COUNT(*) FROM public.enrollments WHERE status = 'active'),
        (SELECT COUNT(*) FROM public.enrollments WHERE status = 'completed'),
        (SELECT COUNT(DISTINCT user_id) FROM public.enrollments);
$$;

-- =========================================================
-- 8. Seed data (mirrors the frontend mock catalog)
-- =========================================================

INSERT INTO public.users (id, email, password_hash, first_name, last_name, account_status)
VALUES
    (1, 'sarah.j@example.com', '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Sarah', 'Jenkins', 'ACTIVE'),
    (2, 'david.m@example.com', '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'David', 'Miller', 'ACTIVE'),
    (3, 'omar.h@example.com', '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Omar', 'Haddad', 'ACTIVE'),
    (4, 'priya.s@example.com', '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Priya', 'Sharma', 'ACTIVE'),
    (5, 'maya.p@example.com', '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Maya', 'Patel', 'SUSPENDED'),
    (6, 'lena.f@example.com', '$2b$10$PWVI93rJHZRyXqOWBtML.OEKjv4JqnOI7tJM6ftWhO.TnUhmFSbqC', 'Lena', 'Fischer', 'DISABLED')
ON CONFLICT DO NOTHING;

INSERT INTO public.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM public.users u
JOIN public.roles r ON r.name IN ('STUDENT', 'INSTRUCTOR', 'ADMIN')
WHERE (u.email, r.name) IN (
    ('sarah.j@example.com', 'STUDENT'),
    ('david.m@example.com', 'INSTRUCTOR'),
    ('david.m@example.com', 'STUDENT'),
    ('omar.h@example.com', 'ADMIN'),
    ('priya.s@example.com', 'STUDENT'),
    ('maya.p@example.com', 'STUDENT'),
    ('lena.f@example.com', 'STUDENT')
)
ON CONFLICT DO NOTHING;

INSERT INTO public.courses (id, title, status, description)
VALUES
    (1, 'Database Design Fundamentals', 'PUBLISHED', 'Core concepts of relational database design: ER modeling and normalization.'),
    (2, 'SQL & Query Optimization', 'PUBLISHED', 'Write efficient SQL and learn how indexes and query plans work.'),
    (3, 'Intro to Neo4j Graph Databases', 'PUBLISHED', 'Model connected data with graphs and query it with Cypher.'),
    (4, 'Python for Data Science', 'PUBLISHED', 'Practical Python for data analysis with pandas and Jupyter.'),
    (5, 'Modern React & TypeScript', 'PENDING', 'Build type-safe React applications with modern hooks and tooling.'),
    (6, 'Data Warehousing & ETL', 'DRAFT', 'Design data warehouses and build ETL pipelines.')
ON CONFLICT DO NOTHING;

INSERT INTO public.lessons (course_id, title, sequence_order)
VALUES
    (1, 'Introduction to Databases', 1),
    (1, 'Entity-Relationship Modeling', 2),
    (1, 'First Normal Form', 3),
    (1, 'Normalizing to 3NF', 4),
    (2, 'SELECT and Joins', 1),
    (2, 'Subqueries and CTEs', 2),
    (2, 'Indexes', 3),
    (2, 'Reading Query Plans', 4),
    (3, 'Why Graph Databases', 1),
    (3, 'Cypher Basics', 2),
    (4, 'Python Intro', 1),
    (4, 'Pandas DataFrames', 2);

INSERT INTO public.tracks (id, title, status, description)
VALUES (1, 'Database Engineer', 'PUBLISHED', 'From schema design to query optimization and graph modeling.')
ON CONFLICT DO NOTHING;

INSERT INTO public.track_courses (track_id, course_id, sequence_order)
VALUES (1, 1, 1), (1, 2, 2), (1, 3, 3);

-- NOTE: the course_prerequisites seed row belongs to the prerequisite
-- module and is applied by that module, not by enrollment.

-- Demo student (Sarah, id 1): completes course 1, then joins the
-- Database Engineer track. Enrolling in the track auto-enrolls the
-- remaining published courses with source = 'track'.
INSERT INTO public.enrollments (user_id, course_id, source)
VALUES (1, 1, 'standalone');

UPDATE public.lesson_progress lp
SET status = 'completed',
    completed_at = CURRENT_TIMESTAMP
FROM public.enrollments e
WHERE lp.enrollment_id = e.id
  AND e.user_id = 1
  AND e.course_id = 1;

SELECT public.sp_enroll_track(1, 1);
