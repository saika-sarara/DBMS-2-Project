-- =========================================================
-- V18: Replace course curriculum (authoring)
--
-- The instructor course editor persists modules + lessons as one
-- atomic save. Rather than diffing each module/lesson through the
-- per-row procedures, this procedure replaces the whole curriculum
-- of a course in a single transaction:
--   * enforces ownership + editable state (fn_require_course_manager,
--     fn_course_is_editable), so the DB keeps owning the rules
--   * deletes the existing modules (lessons cascade) and inserts
--     the incoming modules/lessons with fresh sequence orders
--   * refreshes the denormalized aggregates (total_lessons /
--     estimated_duration_minutes)
--
-- Payload shape (JSONB):
--   [{ "title": "...", "description": "...",
--      "lessons": [{ "title": "...", "estimatedDurationMinutes": 0,
--                    "isPreview": false }] }]
-- =========================================================

CREATE OR REPLACE FUNCTION public.sp_replace_course_curriculum(
    p_actor_id BIGINT,
    p_course_id BIGINT,
    p_modules  JSONB
)
RETURNS TABLE (
    course_id   BIGINT,
    module_count BIGINT,
    lesson_count BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_course_status VARCHAR(20);
    v_module        JSONB;
    v_lesson        JSONB;
    v_module_order  INTEGER;
    v_lesson_order  INTEGER;
    v_new_module_id BIGINT;
    v_module_count  BIGINT := 0;
    v_lesson_count  BIGINT := 0;
    v_title         VARCHAR;
BEGIN
    SELECT c.status, c.title INTO v_course_status, v_title
    FROM public.courses c
    WHERE c.id = p_course_id;

    IF v_course_status IS NULL THEN
        RAISE EXCEPTION 'LTC11: Course % does not exist.', p_course_id
            USING ERRCODE = 'LTC11';
    END IF;

    PERFORM public.fn_require_course_manager(p_course_id, p_actor_id);

    IF NOT public.fn_course_is_editable(p_course_id) THEN
        RAISE EXCEPTION 'LTC12: Course is not editable. Only draft or rejected courses can be edited.'
            USING ERRCODE = 'LTC12';
    END IF;

    IF p_modules IS NULL THEN
        p_modules := '[]'::JSONB;
    END IF;

    -- Lessons cascade with their module; content blocks cascade with lessons.
    -- Flat lessons (module_id IS NULL) are not reached by that cascade, so
    -- remove them explicitly to guarantee a full replace.
    DELETE FROM public.modules WHERE course_id = p_course_id;
    DELETE FROM public.lessons
    WHERE course_id = p_course_id AND module_id IS NULL;

    v_module_order := 0;

    FOR v_module IN
        SELECT value FROM jsonb_array_elements(p_modules)
    LOOP
        v_module_order := v_module_order + 1;

        v_title := COALESCE(v_module->>'title', '');

        IF BTRIM(v_title) = '' THEN
            RAISE EXCEPTION 'LTC13: Module title is required.'
                USING ERRCODE = 'LTC13';
        END IF;

        INSERT INTO public.modules (course_id, title, description, sequence_order)
        VALUES (
            p_course_id,
            BTRIM(v_title),
            v_module->>'description',
            v_module_order
        )
        RETURNING id INTO v_new_module_id;

        v_module_count := v_module_count + 1;

        v_lesson_order := 0;

        FOR v_lesson IN
            SELECT value
            FROM jsonb_array_elements(COALESCE(v_module->'lessons', '[]'::JSONB))
        LOOP
            v_lesson_order := v_lesson_order + 1;

            v_title := COALESCE(v_lesson->>'title', '');

            IF BTRIM(v_title) = '' THEN
                RAISE EXCEPTION 'LTC13: Lesson title is required.'
                    USING ERRCODE = 'LTC13';
            END IF;

            INSERT INTO public.lessons (
                course_id,
                module_id,
                title,
                sequence_order,
                estimated_duration_minutes,
                is_preview
            )
            VALUES (
                p_course_id,
                v_new_module_id,
                BTRIM(v_title),
                v_lesson_order,
                GREATEST(COALESCE((v_lesson->>'estimatedDurationMinutes')::INTEGER, 0), 0),
                COALESCE((v_lesson->>'isPreview')::BOOLEAN, FALSE)
            );

            v_lesson_count := v_lesson_count + 1;
        END LOOP;
    END LOOP;

    PERFORM public.fn_update_course_aggregate_counts(p_course_id);

    course_id   := p_course_id;
    module_count := v_module_count;
    lesson_count := v_lesson_count;
    RETURN NEXT;
    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF SQLSTATE IN ('LTC10', 'LTC11', 'LTC12', 'LTC13', '23505', '23502', '23503') THEN
            RAISE;
        END IF;
        RAISE LOG 'sp_replace_course_curriculum unexpected sqlstate=%: %', SQLSTATE, SQLERRM;
        RAISE EXCEPTION 'LT500: Unexpected database error while replacing the curriculum: %', SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;
