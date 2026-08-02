CREATE TABLE IF NOT EXISTS course_bypasses (
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    target_course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    prerequisite_course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    passed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, target_course_id, prerequisite_course_id)
);