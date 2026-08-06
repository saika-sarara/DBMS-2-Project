-- =========================================================
-- sp_publish_course
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_publish_course(
    p_admin_id  BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id    BIGINT,
    title        VARCHAR,
    slug         VARCHAR,
    status       VARCHAR,
    published_by BIGINT,
    published_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    IF NOT public.fn_user_has_role(p_admin_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can publish courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    SELECT c.status INTO v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    IF v_status NOT IN ('PENDING_REVIEW', 'REJECTED') THEN
        RAISE EXCEPTION 'LTC12: Only pending or rejected courses can be published.'
            USING ERRCODE = 'LTC12';
    END IF;

    UPDATE public.courses
    SET status = 'PUBLISHED',
        published_by = p_admin_id,
        published_at = CURRENT_TIMESTAMP,
        rejection_reason = NULL
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.published_by,
        public.courses.published_at
    INTO course_id, title, slug, status, published_by, published_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11', 'LTC12') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_publish_course unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while publishing the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
