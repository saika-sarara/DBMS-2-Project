-- =========================================================
-- sp_reject_course
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_reject_course(
    p_admin_id  BIGINT,
    p_course_id BIGINT,
    p_reason    TEXT
)
RETURNS TABLE (
    course_id        BIGINT,
    title            VARCHAR,
    slug             VARCHAR,
    status           VARCHAR,
    rejection_reason TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    IF NOT public.fn_user_has_role(p_admin_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can reject courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    IF p_reason IS NULL OR BTRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'LTC13: A rejection reason is required.'
            USING ERRCODE = 'LTC13';
    END IF;

    SELECT c.status INTO v_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    IF v_status <> 'PENDING_REVIEW' THEN
        RAISE EXCEPTION 'LTC12: Only pending courses can be rejected.'
            USING ERRCODE = 'LTC12';
    END IF;

    UPDATE public.courses
    SET status = 'REJECTED',
        rejection_reason = BTRIM(p_reason)
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status,
        public.courses.rejection_reason
    INTO course_id, title, slug, status, rejection_reason;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11', 'LTC12', 'LTC13') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_reject_course unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while rejecting the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
