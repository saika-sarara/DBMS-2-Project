-- Supports: per-enrollment progress calculation and lock-state
-- checks performed by the progress triggers.
CREATE INDEX IF NOT EXISTS idx_lesson_progress_enrollment_status
ON lesson_progress(enrollment_id, status);
