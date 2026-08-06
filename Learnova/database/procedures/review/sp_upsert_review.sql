-- =========================================================
-- sp_upsert_review
--
-- PROCEDURE for the review feature.
-- Source of truth: review.sql (V11). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 3. Review write path
-- Inserts or updates the student's review for a published course they
-- are enrolled in. One review per student/course (upsert).

CREATE OR REPLACE FUNCTION public.sp_upsert_review(
    p_student_id BIGINT,
    p_course_id  BIGINT,
    p_rating     SMALLINT,
    p_comment    TEXT
)
RETURNS TABLE (
    review_id  BIGINT,
    user_id    BIGINT,
    course_id  BIGINT,
    rating     SMALLINT,
    comment    TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_status VARCHAR(20);
    v_enrolled      BOOLEAN;
BEGIN
    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'LTR01: Rating must be between 1 and 5.'
            USING ERRCODE = 'LTR01';
    END IF;

    SELECT c.status
    INTO v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_course_status IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    IF v_course_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'LTR02: Only published courses can be reviewed.'
            USING ERRCODE = 'LTR02';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.enrollments
        WHERE user_id = p_student_id
          AND course_id = p_course_id
          AND status IN ('active', 'completed')
    )
    INTO v_enrolled;

    IF NOT v_enrolled THEN
        RAISE EXCEPTION 'LTR03: Enroll in the course before leaving a review.'
            USING ERRCODE = 'LTR03';
    END IF;

    INSERT INTO public.reviews (user_id, course_id, rating, comment)
    VALUES (p_student_id, p_course_id, p_rating, NULLIF(BTRIM(COALESCE(p_comment, '')), ''))
    ON CONFLICT (user_id, course_id) DO UPDATE
        SET rating = EXCLUDED.rating,
            comment = EXCLUDED.comment
    RETURNING
        public.reviews.id,
        public.reviews.user_id,
        public.reviews.course_id,
        public.reviews.rating,
        public.reviews.comment,
        public.reviews.created_at,
        public.reviews.updated_at
    INTO review_id, user_id, course_id, rating, comment, created_at, updated_at;

    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC11', 'LTR01', 'LTR02', 'LTR03') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_upsert_review unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while saving the review: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
