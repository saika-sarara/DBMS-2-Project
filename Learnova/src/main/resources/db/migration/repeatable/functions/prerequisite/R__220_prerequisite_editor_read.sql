-- ============================================================
-- Learnova
-- Current prerequisite editor read model
--
-- Purpose:
--   * one database call loads the entire prerequisite editor
--   * target course metadata
--   * current prerequisite definitions
--   * selectable prerequisite candidates
--
-- Prerequisite eligibility itself remains owned by R__210.
-- ============================================================


-- ============================================================
-- 1. Candidate visibility
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_prerequisite_candidate_is_selectable(
    p_actor_id BIGINT,
    p_target_course_id BIGINT,
    p_candidate_course_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.courses candidate
        WHERE candidate.id = p_candidate_course_id
          AND candidate.id <> p_target_course_id
          AND candidate.status <> 'ARCHIVED'
          AND (
                candidate.status = 'PUBLISHED'
                OR candidate.instructor_id = p_actor_id
                OR public.fn_user_has_role(
                    p_actor_id,
                    'ADMIN'
                )
          )
    );
$$;

-- ============================================================
-- 2. Complete prerequisite editor bootstrap
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_prerequisite_editor(
    p_actor_id BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    target_course_id BIGINT,
    target_title VARCHAR,
    target_slug VARCHAR,
    target_status TEXT,
    editable BOOLEAN,
    prerequisites JSONB,
    candidates JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_course_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM public.courses c
            WHERE c.id = p_course_id
       )
    THEN
        RAISE EXCEPTION
            'LTP01: Course % does not exist.',
            p_course_id
            USING ERRCODE = 'LTP01';
    END IF;
    PERFORM public.fn_require_course_manager(
        p_course_id,
        p_actor_id
    );
    RETURN QUERY
    SELECT
        c.id,
        c.title,
        c.slug,
        LOWER(c.status)::TEXT,
        public.fn_course_is_editable(c.id),
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'courseId',
                        prerequisite_course.id,
                        'title',
                        prerequisite_course.title,
                        'slug',
                        prerequisite_course.slug,
                        'status',
                        LOWER(
                            prerequisite_course.status
                        ),
                        'requiredMinScore',
                        cp.required_min_score
                    )
                    ORDER BY
                        LOWER(
                            prerequisite_course.title
                        ),
                        prerequisite_course.id
                )
                FROM public.course_prerequisites cp
                JOIN public.courses prerequisite_course
                  ON prerequisite_course.id =
                     cp.prerequisite_course_id
                WHERE cp.course_id =
                      c.id
            ),
            '[]'::JSONB
        ),
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'courseId',
                        candidate.id,
                        'title',
                        candidate.title,
                        'slug',
                        candidate.slug,
                        'status',
                        LOWER(candidate.status)
                    )
                    ORDER BY
                        LOWER(candidate.title),
                        candidate.id
                )
                FROM public.courses candidate
                WHERE public.fn_prerequisite_candidate_is_selectable(
                    p_actor_id,
                    c.id,
                    candidate.id
                )
                  AND NOT EXISTS (
                      SELECT 1
                      FROM public.course_prerequisites current_prerequisite
                      WHERE current_prerequisite.course_id =
                            c.id
                        AND current_prerequisite.prerequisite_course_id =
                            candidate.id
                  )
            ),
            '[]'::JSONB
        )
    FROM public.courses c
    WHERE c.id =
          p_course_id;
    RETURN;
END;
$$;