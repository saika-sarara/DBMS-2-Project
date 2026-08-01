CREATE TABLE IF NOT EXISTS prerequisites (
    course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    prerequisite_course_id BIGINT REFERENCES courses(id) ON DELETE CASCADE,
    PRIMARY KEY (course_id, prerequisite_course_id)
);