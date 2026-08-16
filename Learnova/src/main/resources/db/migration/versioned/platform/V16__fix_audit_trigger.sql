-- =========================================================
-- V16: Fix the generic audit trigger for composite-PK tables
--
-- fn_audit_trigger (created by V14) reads NEW.id / OLD.id to fill
-- audit_logs.record_id. That works for id-based tables but breaks
-- on tables whose primary key is composite and has no id column:
--   * user_roles            (PRIMARY KEY (user_id, role_id))
--   * course_prerequisites  (PRIMARY KEY (course_id, prerequisite_course_id))
-- Every INSERT/UPDATE/DELETE on those tables raised
--   record "new" has no field "id"
-- which broke V17's role seeding AND the live role-grant / prerequisite
-- flows. This migration replaces the trigger so record_id is resolved
-- from the table's own primary key (first key column), which works for
-- id-based and composite-PK tables alike.
--
-- It also fixes a second latent bug: TG_TABLE_NAME has type `name`,
-- which has no implicit cast to the VARCHAR parameter of fn_write_audit,
-- so the trigger call had to be cast (TG_TABLE_NAME::VARCHAR) or the
-- audit insert failed with "function fn_write_audit(...) does not exist".
--
-- Idempotent (CREATE OR REPLACE FUNCTION).
-- =========================================================

CREATE OR REPLACE FUNCTION public.fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor    BIGINT;
    v_action   VARCHAR(50);
    v_table    VARCHAR(100);
    v_record   BIGINT;
    v_pk_col   TEXT;
    v_old_json JSONB;
    v_new_json JSONB;
BEGIN
    v_actor := public.fn_audit_actor();

    -- Resolve the first primary-key column of the table the trigger fired
    -- on, so the generic trigger also works on composite-PK tables
    -- (user_roles, course_prerequisites) that have no `id` column.
    SELECT a.attname
    INTO v_pk_col
    FROM pg_index i
    JOIN pg_attribute a
      ON a.attrelid = i.indrelid
     AND a.attnum = i.indkey[0]
    WHERE i.indrelid = TG_RELID
      AND i.indisprimary
    LIMIT 1;

    v_pk_col := COALESCE(v_pk_col, 'id');

    IF TG_OP = 'INSERT' THEN
        v_action := 'INSERT';
        v_record := (TO_JSONB(NEW) ->> v_pk_col)::BIGINT;
        v_new_json := TO_JSONB(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'UPDATE';
        v_record := (TO_JSONB(NEW) ->> v_pk_col)::BIGINT;
        v_old_json := TO_JSONB(OLD);
        v_new_json := TO_JSONB(NEW);
    ELSE
        v_action := 'DELETE';
        v_record := (TO_JSONB(OLD) ->> v_pk_col)::BIGINT;
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
        TG_TABLE_NAME::VARCHAR,
        v_record,
        v_action,
        v_old_json,
        v_new_json,
        v_actor
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;
