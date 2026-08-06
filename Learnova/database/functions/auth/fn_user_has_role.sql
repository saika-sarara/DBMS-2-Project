-- =========================================================
-- fn_user_has_role
--
-- FUNCTION for the auth feature.
-- Source of truth: auth.sql (V2). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Role-check helpers (used across every module)

CREATE OR REPLACE FUNCTION public.fn_user_has_role(
    p_user_id   BIGINT,
    p_role_name VARCHAR
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON r.id = ur.role_id
        WHERE ur.user_id = p_user_id
          AND r.name = UPPER(BTRIM(p_role_name))
    );
$$;
