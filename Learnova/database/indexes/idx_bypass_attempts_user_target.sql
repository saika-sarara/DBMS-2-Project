-- =========================================================
-- idx_bypass_attempts_user_target
--
-- INDEX for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_bypass_attempts_user_target
    ON public.bypass_attempts (user_id, target_course_id);
