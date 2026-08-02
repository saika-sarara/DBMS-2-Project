CREATE TABLE IF NOT EXISTS bypass_attempts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    target_course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    prerequisite_course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    attempt_date DATE DEFAULT CURRENT_DATE,
    attempt_no INT NOT NULL,
    status VARCHAR(20) DEFAULT 'in_progress',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    submitted_at TIMESTAMP WITH TIME ZONE,
    score_pct DECIMAL(5,2),
    passed BOOLEAN
);

CREATE TABLE IF NOT EXISTS bypass_attempt_questions (
    attempt_id BIGINT REFERENCES bypass_attempts(id) ON DELETE CASCADE,
    source_question_id BIGINT REFERENCES quiz_questions(id) ON DELETE CASCADE,
    PRIMARY KEY (attempt_id, source_question_id)
);

CREATE TABLE IF NOT EXISTS bypass_attempt_answers (
    attempt_id BIGINT REFERENCES bypass_attempts(id) ON DELETE CASCADE,
    source_question_id BIGINT REFERENCES quiz_questions(id) ON DELETE CASCADE,
    selected_option_id BIGINT REFERENCES quiz_options(id) ON DELETE CASCADE,
    is_correct BOOLEAN,
    answered_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attempt_id, source_question_id)
);