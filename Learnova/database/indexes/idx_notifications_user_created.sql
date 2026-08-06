-- =========================================================
-- idx_notifications_user_created
--
-- INDEX for the notification feature.
-- Source of truth: notification.sql (V13). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Notification indexes

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON public.notifications (user_id, created_at DESC);
