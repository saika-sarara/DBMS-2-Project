-- =========================================================
-- trg_validate_content_block
--
-- TRIGGER for the course feature.
-- Source of truth: courses.sql (V4). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.fn_validate_content_block()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.block_type IN ('markdown', 'code')
       AND (NEW.body_markdown IS NULL OR btrim(NEW.body_markdown) = '') THEN
        RAISE EXCEPTION 'LTC20: A % block requires body_markdown content.', NEW.block_type
            USING ERRCODE = 'LTC20';
    END IF;

    IF NEW.block_type IN ('youtube', 'pdf', 'link', 'image')
       AND (NEW.resource_url IS NULL OR btrim(NEW.resource_url) = '') THEN
        RAISE EXCEPTION 'LTC20: A % block requires a resource_url.', NEW.block_type
            USING ERRCODE = 'LTC20';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_content_block ON public.lesson_content_blocks;

CREATE TRIGGER trg_validate_content_block
BEFORE INSERT OR UPDATE ON public.lesson_content_blocks
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_content_block();
