CREATE TABLE IF NOT EXISTS courses (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    instructor_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_courses_category ON courses(category_id);
CREATE INDEX IF NOT EXISTS idx_courses_instructor ON courses(instructor_id);