-- =========================================================
-- idx_quiz_questions_quiz
--
-- INDEX for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 6. Quiz indexes

CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz
    ON public.quiz_questions (quiz_id);
