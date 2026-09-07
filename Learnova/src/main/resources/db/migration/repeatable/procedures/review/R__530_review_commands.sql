CREATE OR REPLACE FUNCTION public.sp_create_review(
    p_student_id BIGINT,
    p_course_id BIGINT,
    p_rating SMALLINT,
    p_comment TEXT
)
RETURNS TABLE (
    review_id BIGINT,
    user_id BIGINT,
    course_id BIGINT,
    rating SMALLINT,
    comment TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_status VARCHAR(20);
BEGIN
    IF p_student_id IS NULL THEN
        RAISE EXCEPTION 'LTR03: A student account is required to submit a review.' USING ERRCODE = 'LTR03';
    END IF;
    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'LTR01: Rating must be between 1 and 5.' USING ERRCODE = 'LTR01';
    END IF;

    SELECT c.status INTO v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id USING ERRCODE = 'LTC11';
    END IF;

    IF v_course_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'LTR02: Only published courses can be reviewed.' USING ERRCODE = 'LTR02';
    END IF;
    IF NOT public.fn_student_completed_course(p_student_id, p_course_id) THEN
        RAISE EXCEPTION 'LTR03: Complete the course before leaving a review.' USING ERRCODE = 'LTR03';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.reviews r WHERE r.user_id = p_student_id AND r.course_id = p_course_id
    ) THEN
        RAISE EXCEPTION 'LTR04: You have already reviewed this course. Submitted reviews cannot be edited or replaced.' USING ERRCODE = 'LTR04';
    END IF;

    INSERT INTO public.reviews (
        user_id,
        course_id,
        rating,
        comment
    )
    VALUES (
        p_student_id,
        p_course_id,
        p_rating,
        NULLIF(BTRIM(COALESCE(p_comment, '')), '')
    )
    RETURNING
        public.reviews.id,
        public.reviews.user_id,
        public.reviews.course_id,
        public.reviews.rating,
        public.reviews.comment,
        public.reviews.created_at,
        public.reviews.updated_at
    INTO
        review_id,
        user_id,
        course_id,
        rating,
        comment,
        created_at,
        updated_at;