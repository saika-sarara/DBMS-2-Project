-- =========================================================
-- trg_users_set_updated_at
--
-- TRIGGER for the auth feature.
-- Source of truth: auth.sql (V2). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Automatically maintain users.updated_at

CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();
