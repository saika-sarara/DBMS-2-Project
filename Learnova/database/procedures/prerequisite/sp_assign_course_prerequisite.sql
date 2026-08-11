-- =========================================================
-- sp_assign_course_prerequisite
--
-- PROCEDURE for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 5. Prerequisite management procedures

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
