-- =========================================================
-- V25: Prerequisite minimum-score enforcement
--
-- Required rule (spec): a prerequisite course is satisfied only when the
-- student COMPLETED the course AND scored at least the configured
-- required_min_score.
--
-- Problem fixed: fn_prerequisite_satisfied previously ignored the
-- required_min_score column entirely — it returned TRUE for any completed
-- enrollment, so a prerequisite configured with required_min_score = 90
-- had no effect once the course was marked completed. The column was
-- dead data.
--
-- This migration:
--   1. extends fn_prerequisite_satisfied with a p_required_min_score
--      parameter and enforces it against enrollments.final_score_pct
--   2. passes cp.required_min_score from both call sites
--      (fn_check_prerequisites_met, fn_find_blocking_course)
--   3. one-time backfills final_score_pct on legacy completed enrollments
--      (credited the platform minimum pass score of 60) so the now-strict
--      rule does not lock out completions recorded before score tracking
-- =========================================================

-- =========================================================
-- 1. fn_prerequisite_satisfied — honor required_min_score
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_prerequisite_satisfied(
    p_student_id             BIGINT,
    p_prerequisite_course_id BIGINT,
    p_required_min_score     NUMERIC(5,2) DEFAULT 60.00
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- A bypass pass is an explicit override: it satisfies the prerequisite
    -- regardless of the recorded course score.
    IF EXISTS (
        SELECT 1
        FROM public.course_bypasses
        WHERE user_id = p_student_id
          AND prerequisite_course_id = p_prerequisite_course_id
    ) THEN
        RETURN TRUE;
    END IF;

    -- Completed AND scored at or above the required minimum. A completed
    -- enrollment always carries a score (see the V25 backfill below plus the
    -- quiz/final-assessment paths that record final_score_pct before
    -- completing), so the comparison is strict.
    IF EXISTS (
        SELECT 1
        FROM public.enrollments
        WHERE user_id = p_student_id
          AND course_id = p_prerequisite_course_id
          AND status = 'completed'
          AND final_score_pct >= p_required_min_score
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

-- =========================================================
-- 2. fn_check_prerequisites_met — evaluate each dependency with its own
--    required_min_score
-- =========================================================

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
      AND NOT public.fn_prerequisite_satisfied(
              p_student_id,
              cp.prerequisite_course_id,
              cp.required_min_score
          );

    RETURN v_missing_prereqs = 0;
END;
$$;

-- =========================================================
-- 3. fn_find_blocking_course — same per-dependency score rule
-- =========================================================

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
      AND NOT public.fn_prerequisite_satisfied(
              p_student_id,
              cp.prerequisite_course_id,
              cp.required_min_score
          )
    ORDER BY c.id
    LIMIT 1;

    RETURN;
END;
$$;

-- =========================================================
-- 4. One-time data correction
--
-- Completions recorded before score tracking (the content-only legacy
-- progress path and the original demo seed) have a NULL final_score_pct.
-- Credit them the platform minimum pass score (60 — the quiz default
-- passing_score) so the strict rule above treats them as satisfied and the
-- demo prerequisite chain keeps working.
-- =========================================================

UPDATE public.enrollments
SET final_score_pct = 60.00
WHERE status = 'completed'
  AND final_score_pct IS NULL;
