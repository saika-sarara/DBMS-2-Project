-- =========================================================
-- trg_initialize_lesson_progress
--
-- AFTER INSERT ON enrollments.
-- Creates one locked lesson_progress row for every lesson of the
-- enrolled course. Nothing is unlocked here; unlocking is decided
-- by trg_unlock_first_lesson based on prerequisites.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_initialize_lesson_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO lesson_progress (enrollment_id, lesson_id, status)
    SELECT NEW.id, l.id, 'locked'
    FROM lessons l
    WHERE l.course_id = NEW.course_id
    ON CONFLICT (enrollment_id, lesson_id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_initialize_lesson_progress ON enrollments;
CREATE TRIGGER trg_initialize_lesson_progress
AFTER INSERT ON enrollments
FOR EACH ROW
EXECUTE FUNCTION fn_initialize_lesson_progress();
