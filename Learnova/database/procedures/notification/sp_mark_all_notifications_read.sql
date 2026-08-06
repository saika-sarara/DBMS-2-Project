-- =========================================================
-- sp_mark_all_notifications_read
--
-- PROCEDURE for the notification feature.
-- Source of truth: notification.sql (V13). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE OR REPLACE FUNCTION public.sp_mark_all_notifications_read(p_user_id BIGINT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated BIGINT;
BEGIN
    UPDATE public.notifications
    SET is_read = TRUE
    WHERE user_id = p_user_id
      AND is_read = FALSE;

    GET DIAGNOSTICS v_updated = ROW_COUNT;

    RETURN v_updated;
END;
$$;
