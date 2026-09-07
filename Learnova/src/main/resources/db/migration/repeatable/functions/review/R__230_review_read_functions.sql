-- ============================================================
-- Learnova
-- Current Review read model
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_student_completed_course(
    p_student_id BIGINT,
    p_course_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT
        p_student_id IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM public.enrollments e
            WHERE e.user_id = p_student_id
              AND e.course_id = p_course_id
              AND e.status = 'completed'
        );
$$;

CREATE OR REPLACE FUNCTION public.fn_course_review_state(
    p_student_id BIGINT,
    p_course_id BIGINT
)
RETURNS TABLE (
    course_id BIGINT,
    avg_rating NUMERIC(3,2),
    review_count INTEGER,
    review_state TEXT,
    can_review BOOLEAN,
    own_review JSONB,
    reviews JSONB
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_course_status VARCHAR(20);
    v_has_review BOOLEAN;
    v_completed BOOLEAN;
BEGIN
    SELECT c.status INTO v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id USING ERRCODE = 'LTC11';
    END IF;

    IF v_course_status <> 'PUBLISHED' THEN
        RAISE EXCEPTION 'LTR02: Only published courses can be reviewed.' USING ERRCODE = 'LTR02';
    END IF;

    v_has_review := p_student_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.reviews r WHERE r.user_id = p_student_id AND r.course_id = p_course_id
    );

    v_completed := public.fn_student_completed_course(p_student_id, p_course_id);

    RETURN QUERY
    SELECT
        c.id,
        c.avg_rating,
        c.review_count,
        CASE
            WHEN p_student_id IS NULL THEN 'login_required'
            WHEN v_has_review THEN 'already_reviewed'
            WHEN v_completed THEN 'available'
            ELSE 'complete_course'
        END::TEXT,
        (p_student_id IS NOT NULL AND NOT v_has_review AND v_completed) AS can_review,
        (
            SELECT jsonb_build_object(
                'reviewId', r.id,
                'rating', r.rating,
                'comment', r.comment,
                'createdAt', r.created_at
            )
            FROM public.reviews r
            WHERE r.user_id = p_student_id AND r.course_id = p_course_id
            LIMIT 1
        ) AS own_review,
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'reviewId', r.id,
                        'rating', r.rating,
                        'comment', r.comment,
                        'reviewerName', CONCAT_WS(' ', u.first_name, u.last_name),
                        'createdAt', r.created_at
                    )
                    ORDER BY r.created_at DESC, r.id DESC
                )
                FROM public.reviews r
                JOIN public.users u ON u.id = r.user_id
                WHERE r.course_id = p_course_id
            ),
            '[]'::JSONB
        ) AS reviews
    FROM public.courses c
    WHERE c.id = p_course_id;
    RETURN;
END;
$$;