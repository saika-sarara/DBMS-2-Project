CREATE TABLE IF NOT EXISTS quiz_options (
    id BIGSERIAL PRIMARY KEY,
    question_id BIGINT REFERENCES quiz_questions(id) ON DELETE CASCADE,
    option_label VARCHAR(5), -- A, B, C, D
    option_text TEXT NOT NULL,
    is_correct BOOLEAN DEFAULT FALSE
);