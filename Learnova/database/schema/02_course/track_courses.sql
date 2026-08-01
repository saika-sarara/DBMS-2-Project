CREATE TABLE IF NOT EXISTS track_courses (
    track_id BIGINT REFERENCES tracks(id) ON DELETE CASCADE,
    course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    sequence_order INT NOT NULL,
    PRIMARY KEY (track_id, course_id)
);