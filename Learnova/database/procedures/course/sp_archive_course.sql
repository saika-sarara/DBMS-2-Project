-- =========================================================
-- sp_archive_course
--
-- PROCEDURE for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_archive_course(
    p_admin_id  BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id    BIGINT,
    title        VARCHAR,
    slug         VARCHAR,
    status       VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT public.fn_user_has_role(p_admin_id, 'ADMIN') THEN
        RAISE EXCEPTION 'LTC10: Only administrators can archive courses.'
            USING ERRCODE = 'LTC10';
    END IF;

    UPDATE public.courses
    SET status = 'ARCHIVED'
    WHERE id = p_course_id
    RETURNING
        public.courses.id,
        public.courses.title,
        public.courses.slug,
        public.courses.status
    INTO course_id, title, slug, status;

    IF course_id IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_archive_course unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while archiving the course: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
