CREATE TABLE IF NOT EXISTS track_enrollments (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    track_id BIGINT REFERENCES tracks(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'active', -- active, completed
    progress_pct DECIMAL(5,2) DEFAULT 0.00,
    enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user_id, track_id)
);