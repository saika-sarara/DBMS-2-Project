-- Enable case-insensitive text support.
-- This will be used for user email addresses.
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


-- Automatically update the updated_at column whenever a row changes.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;