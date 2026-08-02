-- Supports: my enrolled tracks, active track lookups,
-- GET /api/v1/enrollments/my-tracks
CREATE INDEX IF NOT EXISTS idx_track_enrollments_user_status
ON track_enrollments(user_id, status);
