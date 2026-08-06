-- =========================================================
-- fn_audit_trigger
--
-- TRIGGER FUNCTION for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 3. Generic audit trigger

CREATE OR REPLACE FUNCTION public.fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor   BIGINT;
    v_action  VARCHAR(50);
    v_table   VARCHAR(100);
    v_record  BIGINT;
    v_old_json JSONB;
    v_new_json JSONB;
BEGIN
    v_actor := public.fn_audit_actor();

    IF TG_OP = 'INSERT' THEN
        v_action := 'INSERT';
        v_record := NEW.id;
        v_new_json := TO_JSONB(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'UPDATE';
        v_record := NEW.id;
        v_old_json := TO_JSONB(OLD);
        v_new_json := TO_JSONB(NEW);
    ELSE
        v_action := 'DELETE';
        v_record := OLD.id;
        v_old_json := TO_JSONB(OLD);
    END IF;

    -- Role grants/revokes are recorded with their own action names so
    -- administrators can audit permission changes specifically.
    IF TG_TABLE_NAME = 'user_roles' THEN
        IF v_action = 'INSERT' THEN
            v_action := 'GRANT_ROLE';
        ELSIF v_action = 'DELETE' THEN
            v_action := 'REVOKE_ROLE';
        END IF;
    END IF;

    PERFORM public.fn_write_audit(
        TG_TABLE_NAME,
        v_record,
        v_action,
        v_old_json,
        v_new_json,
        v_actor
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;
