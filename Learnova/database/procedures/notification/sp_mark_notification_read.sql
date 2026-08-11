-- =========================================================
-- sp_mark_notification_read
--
-- PROCEDURE for the notification feature.
-- Source of truth: notification.sql (V13). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Marks one notification read, but only when it belongs to the caller.

CREATE OR REPLACE FUNCTION public.sp_mark_notification_read(
    p_notification_id BIGINT,
    p_user_id         BIGINT
)
RETURNS TABLE (notification_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.notifications
    SET is_read = TRUE
    WHERE id = p_notification_id
      AND user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'LTNF1: Notification % does not exist for this user.', p_notification_id
            USING ERRCODE = 'LTNF1';
    END IF;

    notification_id := p_notification_id;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE = 'LTNF1' THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_mark_notification_read unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while updating the notification: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
