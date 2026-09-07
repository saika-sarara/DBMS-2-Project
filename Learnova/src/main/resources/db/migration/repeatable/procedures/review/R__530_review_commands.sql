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