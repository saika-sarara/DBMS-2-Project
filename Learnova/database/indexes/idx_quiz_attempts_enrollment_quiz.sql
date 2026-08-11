-- =========================================================
-- idx_quiz_attempts_enrollment_quiz
--
-- INDEX for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_enrollment_quiz
    ON public.quiz_attempts (enrollment_id, quiz_id);
