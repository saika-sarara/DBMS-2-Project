-- =========================================================
-- vw_quiz_public
--
-- VIEW for the quiz feature.
-- Source of truth: quiz.sql (V10). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- Sanitized question bank for taking a quiz (options, but never the
-- is_correct flag).

CREATE OR REPLACE VIEW public.vw_quiz_public AS
SELECT
    q.id                  AS quiz_id,
    q.lesson_id,
    q.title               AS quiz_title,
    q.passing_score,
    q.questions_per_attempt,
    qq.id                 AS question_id,
    qq.question_text,
    qq.sequence_order,
    COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'option_id',     qo.id,
                'option_label',  qo.option_label,
                'option_text',   qo.option_text
            )
            ORDER BY qo.option_label
        ) FILTER (WHERE qo.id IS NOT NULL),
        '[]'::JSONB
    )                     AS options
FROM public.quizzes q
JOIN public.quiz_questions qq ON qq.quiz_id = q.id
LEFT JOIN public.quiz_options qo ON qo.question_id = qq.id
GROUP BY q.id, q.lesson_id, q.title, q.passing_score,
         q.questions_per_attempt, qq.id, qq.question_text, qq.sequence_order;
