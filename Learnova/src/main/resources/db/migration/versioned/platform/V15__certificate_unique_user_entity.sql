-- =========================================================
-- V15: Certificate uniqueness via a partial-unique-index
--
-- PostgreSQL does not allow expressions inside table UNIQUE
-- constraints, so the constraint form of "one certificate per
-- (user, course | track)" cannot be created. The correct shape
-- is a unique index over COALESCE()ed columns. This migration
-- makes that the guaranteed final state on any database:
--   * drops the invalid table constraint if it somehow exists,
--   * ensures the unique index is present (no-op on databases
--     that already applied the fixed V12).
-- Idempotent by construction.
-- =========================================================

ALTER TABLE public.certificates
    DROP CONSTRAINT IF EXISTS uq_certificates_user_entity;

CREATE UNIQUE INDEX IF NOT EXISTS uq_certificates_user_entity
    ON public.certificates (user_id, COALESCE(course_id, 0), COALESCE(track_id, 0));
