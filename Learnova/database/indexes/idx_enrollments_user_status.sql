-- Supports: my enrolled courses, active/course lookups,
-- GET /api/v1/enrollments/my-courses
CREATE INDEX IF NOT EXISTS idx_enrollments_user_status
ON enrollments(user_id, status);
