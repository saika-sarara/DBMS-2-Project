-- =========================================================
-- idx_quiz_options_question
--
-- INDEX for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_quiz_options_question
    ON public.quiz_options (question_id);
