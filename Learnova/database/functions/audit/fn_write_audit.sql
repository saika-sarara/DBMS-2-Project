-- =========================================================
-- fn_write_audit
--
-- FUNCTION for the audit feature.
-- Source of truth: audit.sql (V14). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 2. Write helper

CREATE OR REPLACE FUNCTION public.fn_write_audit(
    p_table_name   VARCHAR,
    p_record_id    BIGINT,
    p_action       VARCHAR,
    p_old_values   JSONB,
    p_new_values   JSONB,
    p_performed_by BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_id BIGINT;
BEGIN
    INSERT INTO public.audit_logs (
        table_name,
        record_id,
        action,
        old_values,
        new_values,
        performed_by
    )
    VALUES (
        p_table_name,
        p_record_id,
        p_action,
        p_old_values,
        p_new_values,
        p_performed_by
    )
    RETURNING public.audit_logs.id
    INTO v_audit_id;

    RETURN v_audit_id;
END;
$$;
