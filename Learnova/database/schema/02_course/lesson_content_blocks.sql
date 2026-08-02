CREATE TABLE IF NOT EXISTS lesson_content_blocks (
    id BIGSERIAL PRIMARY KEY,
    lesson_id BIGINT REFERENCES lessons(id) ON DELETE CASCADE,
    block_type VARCHAR(20) NOT NULL, -- youtube, markdown, blog, pdf
    title VARCHAR(255),
    body_markdown TEXT,
    resource_url TEXT,
    sequence_order INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);