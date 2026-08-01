CREATE TABLE IF NOT EXISTS track_progress (
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    track_id BIGINT REFERENCES tracks(id) ON DELETE CASCADE,
    completion_percentage DECIMAL(5,2) DEFAULT 0.00,
    is_completed BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, track_id)
);