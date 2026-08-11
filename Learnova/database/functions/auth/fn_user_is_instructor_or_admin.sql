-- =========================================================
-- fn_user_is_instructor_or_admin
--
-- FUNCTION for the auth feature.
-- Source of truth: auth.sql (V2). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_user_is_instructor_or_admin(p_user_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT
        public.fn_user_has_role(p_user_id, 'INSTRUCTOR')
        OR public.fn_user_has_role(p_user_id, 'ADMIN');
$$;
