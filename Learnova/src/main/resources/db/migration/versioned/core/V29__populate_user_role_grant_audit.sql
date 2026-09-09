-- =====================================================================
-- V29: Populate user_roles.granted_by / granted_at
--
-- user_roles carries two audit columns that the application never
-- populated:
--   * granted_by  BIGINT          (FK users.id, ON DELETE SET NULL)
--   * granted_at  TIMESTAMPTZ     (NOT NULL DEFAULT CURRENT_TIMESTAMP)
--
-- Default STUDENT grants created during self-registration (and by seed
-- migrations) are system-generated: no human actor exists, so granted_by
-- stays NULL -- exactly the convention used by the V14 audit framework
-- (fn_audit_actor() returns NULL when the 'app.user_id' session setting
-- is absent). Admin-initiated grants carry the authenticated admin.
--
-- This migration adds a BEFORE INSERT/UPDATE trigger that fills the
-- actor from the established 'app.user_id' session setting (read through
-- public.fn_audit_actor(), V14) and guarantees granted_at is never NULL,
-- while preserving any explicitly supplied value.
--
-- Idempotent: CREATE OR REPLACE FUNCTION + DROP TRIGGER IF EXISTS.
-- =====================================================================

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

DROP TRIGGER IF EXISTS trg_user_roles_set_grant_audit ON public.user_roles;
CREATE TRIGGER trg_user_roles_set_grant_audit
BEFORE INSERT OR UPDATE ON public.user_roles
FOR EACH ROW
EXECUTE FUNCTION public.fn_user_role_grant_audit();