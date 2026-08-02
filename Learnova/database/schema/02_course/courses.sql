CREATE TABLE IF NOT EXISTS courses (
    id BIGSERIAL PRIMARY KEY,
    instructor_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    difficulty VARCHAR(20) NOT NULL, -- beginner, intermediate, advanced
    status VARCHAR(20) DEFAULT 'draft', -- draft, pending, published
    min_passing_score DECIMAL(5,2) DEFAULT 60.00,
    avg_rating DECIMAL(3,2) DEFAULT 0.0,
    review_count INT DEFAULT 0,
    submitted_at TIMESTAMP WITH TIME ZONE,
    published_at TIMESTAMP WITH TIME ZONE,
    published_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);