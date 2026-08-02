-- =========================================================
-- V5: Account status refinement
--
-- The platform spec defines exactly three account statuses:
--   ACTIVE, SUSPENDED, BANNED
--
-- V2 shipped with DISABLED in the CHECK constraint and V3 seeded one demo
-- user (lena.f@example.com) with that value. This additive migration:
--   1. Drops the old CHECK (which did not permit BANNED).
--   2. Moves any existing DISABLED rows to BANNED.
--   3. Adds the CHECK for the spec values.
-- No data is dropped and no tables are rewritten.
-- =========================================================

ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS chk_users_account_status;

UPDATE public.users
SET account_status = 'BANNED'
WHERE account_status = 'DISABLED';

ALTER TABLE public.users
    ADD CONSTRAINT chk_users_account_status
    CHECK (account_status IN ('ACTIVE', 'SUSPENDED', 'BANNED'));
