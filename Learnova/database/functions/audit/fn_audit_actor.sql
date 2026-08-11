-- =========================================================
-- fn_audit_actor
--
-- FUNCTION for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Resolves the acting user from the 'app.user_id' session setting.

CREATE OR REPLACE FUNCTION public.fn_audit_actor()
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_id', TRUE), '')::BIGINT;
$$;
