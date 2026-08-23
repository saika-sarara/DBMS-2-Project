-- Function to recalculate enrollment course progress percentage
CREATE OR REPLACE FUNCTION update_course_progress()
RETURNS TRIGGER AS $$
DECLARE
    v_enrollment_id BIGINT;
    v_total_items INT;
    v_completed_items INT;
    v_new_progress NUMERIC(5,2);
BEGIN
    v_enrollment_id := NEW.enrollment_id;

    -- Count total and completed items for the enrolled course
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE completed = TRUE)
    INTO v_total_items, v_completed_items
    FROM student_item_progress
    WHERE enrollment_id = v_enrollment_id;

    IF v_total_items > 0 THEN
        v_new_progress := (v_completed_items::NUMERIC / v_total_items::NUMERIC) * 100.0;
    ELSE
        v_new_progress := 0.0;
    END IF;

    -- Update course enrollment progress percentage
    UPDATE enrollments
    SET progress_percentage = v_new_progress,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_enrollment_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger firing on module/quiz item completion
DROP TRIGGER IF EXISTS trigger_update_course_progress ON student_item_progress;
CREATE TRIGGER trigger_update_course_progress
AFTER INSERT OR UPDATE ON student_item_progress
FOR EACH ROW
EXECUTE FUNCTION update_course_progress();

-- Function to recalculate track progress percentage when course completes
CREATE OR REPLACE FUNCTION update_track_progress()
RETURNS TRIGGER AS $$
DECLARE
    v_student_id BIGINT;
    v_track_id BIGINT;
    v_total_courses INT;
    v_completed_courses INT;
    v_track_progress NUMERIC(5,2);
BEGIN
    v_student_id := NEW.student_id;
    
    -- Find active track enrollments associated with this course
    FOR v_track_id IN 
        SELECT te.track_id 
        FROM track_enrollments te
        JOIN track_courses tc ON tc.track_id = te.track_id
        WHERE te.student_id = v_student_id AND tc.course_id = NEW.course_id
    LOOP
        SELECT 
            COUNT(tc.course_id),
            COUNT(e.id) FILTER (WHERE e.progress_percentage >= 100.0)
        INTO v_total_courses, v_completed_courses
        FROM track_courses tc
        LEFT JOIN enrollments e ON e.course_id = tc.course_id AND e.student_id = v_student_id
        WHERE tc.track_id = v_track_id;

        IF v_total_courses > 0 THEN
            v_track_progress := (v_completed_courses::NUMERIC / v_total_courses::NUMERIC) * 100.0;
        ELSE
            v_track_progress := 0.0;
        END IF;

        UPDATE track_enrollments
        SET progress_percentage = v_track_progress,
            updated_at = CURRENT_TIMESTAMP
        WHERE student_id = v_student_id AND track_id = v_track_id;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger firing when course progress updates
DROP TRIGGER IF EXISTS trigger_update_track_progress ON enrollments;
CREATE TRIGGER trigger_update_track_progress
AFTER INSERT OR UPDATE OF progress_percentage ON enrollments
FOR EACH ROW
EXECUTE FUNCTION update_track_progress();