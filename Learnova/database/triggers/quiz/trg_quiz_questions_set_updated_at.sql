-- =========================================================
-- trg_quiz_questions_set_updated_at
--
-- TRIGGER for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
CREATE TRIGGER trg_quiz_questions_set_updated_at
BEFORE UPDATE ON public.quiz_questions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();
