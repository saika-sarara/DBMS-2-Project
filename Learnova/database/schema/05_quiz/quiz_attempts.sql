CREATE TABLE IF NOT EXISTS quiz_attempts (
    id BIGSERIAL PRIMARY KEY,
    enrollment_id BIGINT REFERENCES enrollments(id) ON DELETE CASCADE,
    quiz_id BIGINT REFERENCES quizzes(id) ON DELETE CASCADE,
    attempt_date DATE DEFAULT CURRENT_DATE,
    attempt_no INT NOT NULL,
    status VARCHAR(20) DEFAULT 'in_progress', -- in_progress, submitted
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    submitted_at TIMESTAMP WITH TIME ZONE,
    score_pct DECIMAL(5,2),
    passed BOOLEAN
);

CREATE TABLE IF NOT EXISTS quiz_attempt_questions (
    attempt_id BIGINT REFERENCES quiz_attempts(id) ON DELETE CASCADE,
    question_id BIGINT REFERENCES quiz_questions(id) ON DELETE CASCADE,
    PRIMARY KEY (attempt_id, question_id)
);

CREATE TABLE IF NOT EXISTS attempt_answers (
    attempt_id BIGINT REFERENCES quiz_attempts(id) ON DELETE CASCADE,
    question_id BIGINT REFERENCES quiz_questions(id) ON DELETE CASCADE,
    selected_option_id BIGINT REFERENCES quiz_options(id) ON DELETE CASCADE,
    is_correct BOOLEAN,
    answered_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attempt_id, question_id)
);