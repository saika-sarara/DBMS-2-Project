CREATE OR REPLACE FUNCTION public.sp_create_review(
    p_student_id BIGINT,
    p_course_id BIGINT,
    p_rating SMALLINT,
    p_comment TEXT
)