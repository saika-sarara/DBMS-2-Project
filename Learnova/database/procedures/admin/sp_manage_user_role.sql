CREATE OR REPLACE PROCEDURE sp_manage_user_role(
    p_user_id BIGINT,
    p_role_name VARCHAR(50),
    p_action VARCHAR(10) -- 'GRANT' or 'REVOKE'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_role_id INT;
BEGIN
    SELECT id INTO v_role_id FROM roles WHERE name = p_role_name;
    
    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Role % does not exist', p_role_name;
    END IF;

    IF p_action = 'GRANT' THEN
        INSERT INTO user_roles (user_id, role_id)
        VALUES (p_user_id, v_role_id)
        ON CONFLICT DO NOTHING;
    ELSIF p_action = 'REVOKE' THEN
        DELETE FROM user_roles 
        WHERE user_id = p_user_id AND role_id = v_role_id;
    ELSE
        RAISE EXCEPTION 'Invalid action: %. Use GRANT or REVOKE.', p_action;
    END IF;
END;
$$;