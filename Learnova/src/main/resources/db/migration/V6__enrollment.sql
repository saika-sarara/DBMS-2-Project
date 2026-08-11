-- =========================================================
-- V6: Enrollment
--
-- All schema for the enrollment feature in one file:
--   * the track catalogue (tracks / track_courses)
--   * the enrollment records (enrollments / track_enrollments)
--   * the prerequisite engine CONTRACT placeholder
--     (fn_prerequisite_engine_course_access) -- owned by the
--     prerequisite module, which replaces only the BODY, never
--     the signature. Enrollment treats it as its only entry point
--     into prerequisite decisions.
--   * the enrollment procedures (sp_enroll_student / sp_enroll_track)
--   * the enrollment triggers (duplicate protection, track auto-enroll)
--   * the fresh admin counters fn_admin_enrollment_stats()
--   * enrollment indexes
--
-- The progress feature (lesson_progress and its triggers) is
-- deployed by V7; it fires against this schema but owns its own
-- tables and triggers.
--
-- The courses / lessons tables come from V4; lessons.sequence_order
-- is the cross-module ordering contract this module relies on.
-- =========================================================

-- =========================================================
-- 1. Tracks
-- =========================================================

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

-- =========================================================
-- 2. Enrollment records
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


-- =========================================================
-- 3. Functions
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

-- NOTE: the lesson-progress triggers (trg_initialize_lesson_progress,
-- trg_unlock_first_lesson, trg_unlock_track_courses_after_completion,
-- trg_update_track_progress) fire on enrollments but belong to the
-- progress feature; they are defined in V7.

-- NOTE: trg_unlock_course_after_bypass is NOT defined here. It reacts to
-- the course_bypasses table, which belongs to the prerequisite module;
-- that module owns the trigger.

-- =========================================================
-- 6. Enrollment indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_enrollments_user_status
    ON public.enrollments (user_id, status);

CREATE INDEX IF NOT EXISTS idx_track_enrollments_user_status
    ON public.track_enrollments (user_id, status);

CREATE INDEX IF NOT EXISTS idx_track_courses_sequence
    ON public.track_courses (track_id, sequence_order);


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
