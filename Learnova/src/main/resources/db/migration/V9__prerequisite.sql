-- =========================================================
-- V9: Prerequisite engine
--
-- All schema for the prerequisite feature in one file:
--   * course_prerequisites (the directed dependency graph)
--   * course_bypasses (a prerequisite satisfied by passing its
--     bypass quiz instead of completing the course)
--   * fn_prerequisite_satisfied / fn_check_prerequisites_met /
--     fn_find_blocking_course -- the per-student rule engine
--   * the REAL body of fn_prerequisite_engine_course_access
--     (created in V6 as a contract placeholder; this migration
--     replaces only the BODY, never the signature)
--   * vw_course_prerequisite_closure -- recursive-CTE dependency
--     view
--   * sp_assign_course_prerequisite / sp_remove_course_prerequisite
--   * cycle-prevention + bypass-unlock triggers
--   * prerequisite indexes + demo dependency chain
--
-- The enrollment module (V6) and the progress module (V7) already
-- delegate every prerequisite DECISION to
-- fn_prerequisite_engine_course_access. From this migration on that
-- contract returns real answers; the enrollment / progress modules
-- need no changes.
-- =========================================================

-- =========================================================
-- 1. Prerequisite tables
-- =========================================================

CREATE TABLE public.course_prerequisites (
    course_id              BIGINT NOT NULL,
    prerequisite_course_id BIGINT NOT NULL,
    required_min_score     NUMERIC(5,2) NOT NULL DEFAULT 60.00,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_course_prerequisites
        PRIMARY KEY (course_id, prerequisite_course_id),

    CONSTRAINT fk_course_prerequisites_course
        FOREIGN KEY (course_id)
        REFERENCES public.courses (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_course_prerequisites_prerequisite
        FOREIGN KEY (prerequisite_course_id)
        REFERENCES public.courses (id)
        ON DELETE CASCADE,

    CONSTRAINT chk_course_prerequisites_not_self
        CHECK (course_id <> prerequisite_course_id),

    CONSTRAINT chk_course_prerequisites_score
        CHECK (required_min_score >= 0 AND required_min_score <= 100)
);

CREATE TABLE public.course_bypasses (
    user_id                BIGINT NOT NULL,
    target_course_id       BIGINT NOT NULL,
    prerequisite_course_id BIGINT NOT NULL,
    passed_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_course_bypasses
        PRIMARY KEY (user_id, target_course_id, prerequisite_course_id),

    CONSTRAINT fk_course_bypasses_user
        FOREIGN KEY (user_id)
        REFERENCES public.users (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_course_bypasses_target
        FOREIGN KEY (target_course_id)
        REFERENCES public.courses (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_course_bypasses_prerequisite
        FOREIGN KEY (prerequisite_course_id)
        REFERENCES public.courses (id)
        ON DELETE CASCADE,

    CONSTRAINT chk_course_bypasses_not_self
        CHECK (target_course_id <> prerequisite_course_id)
);


-- =========================================================
-- 2. Per-student prerequisite rules
-- =========================================================

-- A single prerequisite course is satisfied by the student when the
-- course was completed OR its bypass quiz was passed (a bypass record
-- is keyed on the prerequisite course, for any target course).
CREATE OR REPLACE FUNCTION public.fn_prerequisite_satisfied(
    p_student_id            BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.enrollments
        WHERE user_id = p_student_id
          AND course_id = p_prerequisite_course_id
          AND status = 'completed'
    ) THEN
        RETURN TRUE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.course_bypasses
        WHERE user_id = p_student_id
          AND prerequisite_course_id = p_prerequisite_course_id
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

-- AND-based rule: every prerequisite course of the target course must
-- be satisfied by the student. Returns FALSE as soon as one is missing.
CREATE OR REPLACE FUNCTION public.fn_check_prerequisites_met(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_missing_prereqs INT;
BEGIN
    SELECT COUNT(*)
    INTO v_missing_prereqs
    FROM public.course_prerequisites cp
    WHERE cp.course_id = p_course_id
      AND NOT public.fn_prerequisite_satisfied(p_student_id, cp.prerequisite_course_id);

    RETURN v_missing_prereqs = 0;
END;
$$;

-- First unsatisfied prerequisite course, or an empty set when every
-- prerequisite is satisfied. Used to tell the student what blocks the
-- course.
CREATE OR REPLACE FUNCTION public.fn_find_blocking_course(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    blocking_course_id    BIGINT,
    blocking_course_title TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.title::TEXT
    FROM public.course_prerequisites cp
    JOIN public.courses c ON c.id = cp.prerequisite_course_id
    WHERE cp.course_id = p_course_id
      AND NOT public.fn_prerequisite_satisfied(p_student_id, cp.prerequisite_course_id)
    ORDER BY c.id
    LIMIT 1;

    RETURN;
END;
$$;


-- =========================================================
-- 3. The prerequisite engine contract (REAL body)
--
-- V6 created this function as a contract placeholder that always
-- answered "allowed". This migration replaces only the BODY (the
-- signature stays identical). Enrollment (sp_enroll_student,
-- fn_student_course_access, card status) and progress (lesson-unlock
-- triggers) already treat this function as their ONLY entry point
-- into prerequisite decisions, so they start enforcing prerequisites
-- automatically.
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
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_blocking_id    BIGINT;
    v_blocking_title TEXT;
BEGIN
    IF public.fn_check_prerequisites_met(p_student_id, p_course_id) THEN
        allowed := TRUE;
        reason_code := 'PREREQUISITES_OK';
        message := NULL;
        blocking_course_id := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT bc.blocking_course_id, bc.blocking_course_title
    INTO v_blocking_id, v_blocking_title
    FROM public.fn_find_blocking_course(p_student_id, p_course_id) bc
    LIMIT 1;

    allowed := FALSE;
    reason_code := 'PREREQUISITES_LOCKED';
    message := 'Course is locked until prerequisite "'
               || COALESCE(v_blocking_title, 'a required course')
               || '" is completed or bypassed.';
    blocking_course_id := v_blocking_id;
    RETURN NEXT;
    RETURN;
END;
$$;


-- =========================================================
-- 4. Dependency view (recursive CTE)
-- =========================================================

-- For every course, every course it transitively requires (directly or
-- through a chain) together with the dependency depth. A row
-- (course_id=3, required_course_id=1, depth=2) reads as "course 3
-- cannot be enrolled until course 1 is completed, because course 3
-- requires course 2 which requires course 1."
CREATE OR REPLACE VIEW public.vw_course_prerequisite_closure AS
WITH RECURSIVE prereq_chain AS (
    SELECT cp.course_id,
           cp.prerequisite_course_id AS required_course_id,
           1                          AS depth
    FROM public.course_prerequisites cp

    UNION ALL

    SELECT pc.course_id,
           cp.prerequisite_course_id,
           pc.depth + 1
    FROM prereq_chain pc
    JOIN public.course_prerequisites cp
      ON cp.course_id = pc.required_course_id
)
SELECT pc.course_id,
       c.title AS course_title,
       pc.required_course_id,
       r.title AS required_course_title,
       pc.depth
FROM prereq_chain pc
JOIN public.courses c ON c.id = pc.course_id
JOIN public.courses r ON r.id = pc.required_course_id;


-- =========================================================
-- 5. Prerequisite management procedures
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_assign_course_prerequisite(
    p_actor_id               BIGINT,
    p_course_id              BIGINT,
    p_prerequisite_course_id BIGINT,
    p_required_min_score     NUMERIC(5,2) DEFAULT 60.00
)
RETURNS TABLE (
    course_id              BIGINT,
    prerequisite_course_id BIGINT,
    required_min_score     NUMERIC(5,2),
    created_at             TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    IF p_course_id = p_prerequisite_course_id THEN
        RAISE EXCEPTION 'LTP02: A course cannot be its own prerequisite.'
            USING ERRCODE = 'LTP02';
    END IF;

    INSERT INTO public.course_prerequisites (
        course_id,
        prerequisite_course_id,
        required_min_score
    )
    VALUES (
        p_course_id,
        p_prerequisite_course_id,
        GREATEST(LEAST(COALESCE(p_required_min_score, 60.00), 100), 0)
    )
    ON CONFLICT (course_id, prerequisite_course_id) DO UPDATE
        SET required_min_score = EXCLUDED.required_min_score
    RETURNING
        public.course_prerequisites.course_id,
        public.course_prerequisites.prerequisite_course_id,
        public.course_prerequisites.required_min_score,
        public.course_prerequisites.created_at
    INTO course_id, prerequisite_course_id, required_min_score, created_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTP02', '23505') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_assign_course_prerequisite unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while assigning the prerequisite: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_remove_course_prerequisite(
    p_actor_id               BIGINT,
    p_course_id              BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS TABLE (
    course_id              BIGINT,
    prerequisite_course_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    DELETE FROM public.course_prerequisites
    WHERE course_id = p_course_id
      AND prerequisite_course_id = p_prerequisite_course_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'LTP03: Prerequisite relation for course % on course % does not exist.',
            p_prerequisite_course_id, p_course_id
            USING ERRCODE = 'LTP03';
    END IF;

    course_id := p_course_id;
    prerequisite_course_id := p_prerequisite_course_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTP03') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_remove_course_prerequisite unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while removing the prerequisite: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;


-- =========================================================
-- 6. Prerequisite triggers
-- =========================================================

-- Rejects edges that would close a cycle (the new prerequisite already
-- depends -- directly or transitively -- on the target course).
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

-- When a student passes a bypass quiz (a course_bypasses row lands),
-- unlock the first lesson of every active enrollment whose prerequisites
-- are now satisfied. The decision is delegated to the prerequisite engine
-- contract.
CREATE OR REPLACE FUNCTION public.fn_unlock_course_after_bypass()
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

DROP TRIGGER IF EXISTS trg_unlock_course_after_bypass ON public.course_bypasses;
CREATE TRIGGER trg_unlock_course_after_bypass
AFTER INSERT ON public.course_bypasses
FOR EACH ROW
EXECUTE FUNCTION public.fn_unlock_course_after_bypass();


-- =========================================================
-- 7. Prerequisite indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_course_prerequisites_course
    ON public.course_prerequisites (course_id);

CREATE INDEX IF NOT EXISTS idx_course_prerequisites_prerequisite
    ON public.course_prerequisites (prerequisite_course_id);

CREATE INDEX IF NOT EXISTS idx_course_bypasses_user
    ON public.course_bypasses (user_id);


-- =========================================================
-- 8. Demo dependency chain
--
-- Course 2 (SQL & Query Optimization) requires course 1 (Database
-- Design Fundamentals); course 3 (Intro to Neo4j Graph Databases)
-- requires course 2. This mirrors the Database Engineer track so the
-- prerequisite engine is demonstrable out of the box. The chain is
-- idempotent: re-running against an existing database is a no-op.
-- =========================================================

INSERT INTO public.course_prerequisites (course_id, prerequisite_course_id, required_min_score)
VALUES (2, 1, 60.00), (3, 2, 60.00)
ON CONFLICT (course_id, prerequisite_course_id) DO NOTHING;
