-- =========================================================
-- fn_user_is_active_student
--
-- Returns TRUE only when the user exists, has an ACTIVE account
-- and holds the STUDENT role.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_user_is_active_student(p_user_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_active  BOOLEAN;
    v_is_student BOOLEAN;
BEGIN
    SELECT account_status = 'ACTIVE'
    INTO v_is_active
    FROM users
    WHERE id = p_user_id;

    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = p_user_id
          AND r.name = 'STUDENT'
    )
    INTO v_is_student;

    RETURN COALESCE(v_is_active, FALSE) AND v_is_student;
END;
$$;
