-- =========================================================
-- set_updated_at
--
-- TRIGGER FUNCTION for the shared feature.
-- Source of truth: 00_extensions.sql (V1). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Shared updated_at trigger helper

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;
