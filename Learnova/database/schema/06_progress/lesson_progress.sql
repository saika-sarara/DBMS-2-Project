CREATE TABLE IF NOT EXISTS lesson_progress (
    id BIGSERIAL PRIMARY KEY,
    enrollment_id BIGINT REFERENCES enrollments(id) ON DELETE CASCADE,
    lesson_id BIGINT REFERENCES lessons(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'locked', -- locked, unlocked, completed
    unlocked_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(enrollment_id, lesson_id)
);