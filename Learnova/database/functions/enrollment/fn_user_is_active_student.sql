-- =========================================================
-- fn_user_is_active_student
--
-- FUNCTION for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_user_is_active_student(p_user_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_active  BOOLEAN;
    v_is_student BOOLEAN;
BEGIN
    SELECT account_status = 'ACTIVE'
    INTO v_is_active
    FROM public.users
    WHERE id = p_user_id;

    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = p_user_id
          AND r.name = 'STUDENT'
    )
    INTO v_is_student;

    RETURN COALESCE(v_is_active, FALSE) AND v_is_student;
END;
$$;
