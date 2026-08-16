-- =========================================================
-- V1: Baseline extensions and common helpers
--
-- Shared infrastructure that every later module depends on:
--   * citext    -- case-insensitive text (user email addresses)
--   * pg_trgm   -- trigram index support (course-title search)
--   * unaccent  -- accent-insensitive text (optional, guarded)
--   * set_updated_at() -- shared trigger helper that keeps the
--                        updated_at column current on UPDATE
--
-- These extensions are installed once; subsequent migrations in
-- this project reference them without re-installing.
-- =========================================================

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS unaccent;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'unaccent extension not available; continuing without it.';
END;
$$;


-- =========================================================
-- Shared updated_at trigger helper
-- =========================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;
