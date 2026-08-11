-- =========================================================
-- idx_notifications_user_read
--
-- INDEX for the notification feature.
-- Source of truth: notification.sql (V13). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_read
    ON public.notifications (user_id, is_read);
