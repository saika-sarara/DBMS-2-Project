-- =========================================================
-- fn_course_syllabus
--
-- FUNCTION for the course feature.
-- Source of truth: catalogue.sql (V5). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 8. Syllabus (modules + ordered lessons)

CREATE OR REPLACE FUNCTION public.fn_course_syllabus(
    p_student_id BIGINT,
    p_course_id  BIGINT
)
RETURNS TABLE (
    module_id             BIGINT,
    module_title          VARCHAR,
    module_order          INTEGER,
    lesson_id             BIGINT,
    lesson_title          VARCHAR,
    lesson_order          INTEGER,
    estimated_duration_minutes INTEGER,
    is_preview            BOOLEAN,
    lesson_access_status  TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_course_status VARCHAR(20);
    v_accessible    BOOLEAN;
BEGIN
    SELECT c.status INTO v_course_status
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_course_status IS NULL THEN
        RETURN;
    END IF;

    IF v_course_status <> 'PUBLISHED'
       AND (p_student_id IS NULL
            OR (NOT public.fn_course_is_owned_by(p_course_id, p_student_id)
                AND NOT public.fn_user_has_role(p_student_id, 'ADMIN'))) THEN
        RETURN;
    END IF;

    -- The enrollment contract decides whether this student can open the
    -- course content. Anonymous or non-enrolled students get previews only.
    IF p_student_id IS NULL THEN
        v_accessible := FALSE;
    ELSE
        SELECT COALESCE(ac.is_accessible, FALSE)
        INTO v_accessible
        FROM public.fn_student_course_access(p_student_id, p_course_id) ac;
    END IF;

    RETURN QUERY
    WITH syllabus AS (
        SELECT
            m.id          AS module_id,
            m.title       AS module_title,
            m.sequence_order AS module_order,
            l.id          AS lesson_id,
            l.title       AS lesson_title,
            l.sequence_order AS lesson_order,
            l.estimated_duration_minutes,
            l.is_preview
        FROM public.modules m
        JOIN public.lessons l ON l.module_id = m.id
        WHERE m.course_id = p_course_id
        UNION ALL
        SELECT
            NULL::BIGINT  AS module_id,
            NULL::VARCHAR AS module_title,
            0::INTEGER    AS module_order,
            l.id          AS lesson_id,
            l.title       AS lesson_title,
            l.sequence_order AS lesson_order,
            l.estimated_duration_minutes,
            l.is_preview
        FROM public.lessons l
        WHERE l.course_id = p_course_id
          AND l.module_id IS NULL
    )
    SELECT
        s.module_id,
        s.module_title,
        s.module_order,
        s.lesson_id,
        s.lesson_title,
        s.lesson_order,
        s.estimated_duration_minutes,
        s.is_preview,
        CASE
            WHEN s.is_preview THEN 'preview'
            WHEN v_accessible THEN 'available'
            ELSE 'locked'
        END::TEXT AS lesson_access_status
    FROM syllabus s
    ORDER BY s.module_order ASC, s.lesson_order ASC, s.lesson_id ASC;
END;
$$;
