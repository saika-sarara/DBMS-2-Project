-- =========================================================
-- fn_create_notification
--
-- FUNCTION for the notification feature.
-- Source of truth: notification.sql (V13). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 2. Write helpers

CREATE OR REPLACE FUNCTION public.fn_create_notification(
    p_user_id           BIGINT,
    p_message           TEXT,
    p_related_entity_type VARCHAR DEFAULT NULL,
    p_related_entity_id BIGINT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_notification_id BIGINT;
BEGIN
    INSERT INTO public.notifications (
        user_id,
        message,
        related_entity_type,
        related_entity_id
    )
    VALUES (
        p_user_id,
        p_message,
        p_related_entity_type,
        p_related_entity_id
    )
    RETURNING public.notifications.id
    INTO v_notification_id;

    RETURN v_notification_id;
END;
$$;
