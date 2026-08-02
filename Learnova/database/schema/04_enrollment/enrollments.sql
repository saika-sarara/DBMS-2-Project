CREATE TABLE IF NOT EXISTS enrollments (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'active', -- active, completed
    progress_pct DECIMAL(5,2) DEFAULT 0.00,
    final_score_pct DECIMAL(5,2),
    enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    source VARCHAR(20) DEFAULT 'standalone', -- standalone, track
    UNIQUE(user_id, course_id)
);