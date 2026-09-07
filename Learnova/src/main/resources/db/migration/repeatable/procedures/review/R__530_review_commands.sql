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