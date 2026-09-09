-- ============================================================
-- Learnova
-- Current user_roles grant-audit trigger
--
-- Populates the audit columns on public.user_roles:
--   * granted_by -- actor read from the 'app.user_id' session
--     setting through public.fn_audit_actor() (established in
--     V14). When the setting is absent (direct psql, seed and
--     system-generated grants such as self-registration), it
--     stays NULL -- the same convention the audit framework
--     uses and seed migrations follow.
--   * granted_at -- server-side CURRENT_TIMESTAMP, preserving
--     any explicitly supplied value.
--
-- Idempotent: CREATE OR REPLACE FUNCTION + DROP TRIGGER IF
-- EXISTS, so this repeatable file owns the CURRENT definition.
-- ============================================================


CREATE OR REPLACE FUNCTION public.fn_user_role_grant_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.granted_by IS NULL THEN
        NEW.granted_by := public.fn_audit_actor();
    END IF;

    NEW.granted_at := COALESCE(NEW.granted_at, CURRENT_TIMESTAMP);

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS
    trg_user_roles_set_grant_audit
ON public.user_roles;


CREATE TRIGGER
    trg_user_roles_set_grant_audit

BEFORE INSERT OR UPDATE
ON public.user_roles

FOR EACH ROW

EXECUTE FUNCTION
    public.fn_user_role_grant_audit();