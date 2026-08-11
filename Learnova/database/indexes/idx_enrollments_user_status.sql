-- =========================================================
-- idx_enrollments_user_status
--
-- INDEX for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- NOTE: the lesson-progress triggers (trg_initialize_lesson_progress,
-- trg_unlock_first_lesson, trg_unlock_track_courses_after_completion,
-- trg_update_track_progress) fire on enrollments but belong to the
-- progress feature; they are defined in V7.
-- NOTE: trg_unlock_course_after_bypass is NOT defined here. It reacts to
-- the course_bypasses table, which belongs to the prerequisite module;
-- that module owns the trigger.
-- 6. Enrollment indexes

CREATE INDEX IF NOT EXISTS idx_enrollments_user_status
    ON public.enrollments (user_id, status);
