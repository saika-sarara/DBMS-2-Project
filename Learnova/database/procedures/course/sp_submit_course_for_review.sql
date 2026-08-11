-- =========================================================
-- sp_submit_course_for_review
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_submit_course_for_review(
    p_actor_id  BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id    BIGINT,
    title        VARCHAR,
    slug         VARCHAR,
    status       VARCHAR,
    submitted_at TIMESTAMPTZ,
    rejection_reason TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status      VARCHAR(20);
    v_module_cnt  BIGINT;
    v_lesson_cnt  BIGINT;
BEGIN
    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    SELECT c.status, c.rejection_reason
    INTO v_status, rejection_reason
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status = 'ARCHIVED' THEN
        RAISE EXCEPTION 'LTC12: Archived courses cannot be submitted for review.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF v_status NOT IN ('DRAFT', 'REJECTED') THEN
        RAISE EXCEPTION 'LTC12: Course is not in an editable state.'
            USING ERRCODE = 'LTC12';
    END IF;

    SELECT COUNT(*)::BIGINT INTO v_module_cnt
    FROM public.modules WHERE modules.course_id = p_course_id;

    SELECT COUNT(*)::BIGINT INTO v_lesson_cnt
    FROM public.lessons WHERE lessons.course_id = p_course_id;

    IF v_module_cnt < 1 THEN
        RAISE EXCEPTION 'LTC14: Course must contain at least one module before review.'
            USING ERRCODE = 'LTC14';
    END IF;

    IF v_lesson_cnt < 1 THEN
        RAISE EXCEPTION 'LTC14: Course must contain at least one lesson before review.'
            USING ERRCODE = 'LTC14';
    END IF;

    UPDATE public.courses
    SET status = 'PENDING_REVIEW',
        submitted_at = CURRENT_TIMESTAMP,
        rejection_reason = NULL
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.submitted_at,
        public.courses.rejection_reason
    INTO course_id, title, slug, status, submitted_at, rejection_reason;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC12', 'LTC14') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_submit_course_for_review unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while submitting the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
