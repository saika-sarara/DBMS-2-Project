CREATE TABLE IF NOT EXISTS course_prerequisites (
    course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    prerequisite_course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    required_min_score DECIMAL(5,2) DEFAULT 60.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (course_id, prerequisite_course_id)
);