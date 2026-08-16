-- ============================================================
-- Learnova
-- Current prerequisite command functions
--
-- PostgreSQL calls these "functions"; the sp_* prefix is kept
-- because it is already the project's command-function naming
-- convention.
--
-- Owns:
--   * assign one prerequisite
--   * remove one prerequisite
--   * atomically replace the complete prerequisite set
--
-- All writes:
--   * enforce course ownership
--   * enforce editable course lifecycle
--   * validate candidate visibility
--   * validate minimum scores
--   * rely on R__320 for graph validation
-- ============================================================


-- ============================================================
-- 1. Assign / update one prerequisite
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_assign_course_prerequisite(
    p_actor_id BIGINT,
    p_course_id BIGINT,
    p_prerequisite_course_id BIGINT,
    p_required_min_score NUMERIC(5,2) DEFAULT 60.00
)
RETURNS TABLE (
    course_id BIGINT,
    prerequisite_course_id BIGINT,
    required_min_score NUMERIC(5,2),
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_score NUMERIC(5,2);
BEGIN
    IF p_course_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM public.courses c
            WHERE c.id = p_course_id
       )
    THEN
        RAISE EXCEPTION
            'LTP01: Course % does not exist.',
            p_course_id
            USING ERRCODE = 'LTP01';
    END IF;
    PERFORM public.fn_require_course_manager(
        p_course_id,
        p_actor_id
    );
    IF NOT public.fn_course_is_editable(
        p_course_id
    )
    THEN
        RAISE EXCEPTION
            'LTC12: Prerequisites can only be edited while the course is draft or rejected.'
            USING ERRCODE = 'LTC12';
    END IF;
    IF p_course_id =
       p_prerequisite_course_id
    THEN
        RAISE EXCEPTION
            'LTP02: A course cannot be its own prerequisite.'
            USING ERRCODE = 'LTP02';
    END IF;
    v_score :=
        COALESCE(
            p_required_min_score,
            60.00
        );
    IF v_score < 0
       OR v_score > 100
    THEN
        RAISE EXCEPTION
            'LTP05: requiredMinScore must be between 0 and 100.'
            USING ERRCODE = 'LTP05';
    END IF;
    IF NOT public.fn_prerequisite_candidate_is_selectable(
        p_actor_id,
        p_course_id,
        p_prerequisite_course_id
    )
    THEN
        RAISE EXCEPTION
            'LTP05: Course % is not available as a prerequisite.',
            p_prerequisite_course_id
            USING ERRCODE = 'LTP05';
    END IF;
    INSERT INTO public.course_prerequisites (
        course_id,
        prerequisite_course_id,
        required_min_score
    )
    VALUES (
        p_course_id,
        p_prerequisite_course_id,
        v_score
    )
    ON CONFLICT (
        course_id,
        prerequisite_course_id
    )
    DO UPDATE
    SET required_min_score =
        EXCLUDED.required_min_score
    RETURNING
        public.course_prerequisites.course_id,
        public.course_prerequisites.prerequisite_course_id,
        public.course_prerequisites.required_min_score,
        public.course_prerequisites.created_at
    INTO
        course_id,
        prerequisite_course_id,
        required_min_score,
        created_at;
    RETURN NEXT;
    RETURN;
EXCEPTION
    WHEN OTHERS THEN

        IF SQLSTATE IN (
            'LTP01',
            'LTP02',
            'LTP04',
            'LTP05',
            'LTC10',
            'LTC12',
            '23503',
            '23505'
        )
        THEN
            RAISE;
        END IF;
        RAISE LOG
            'sp_assign_course_prerequisite unexpected sqlstate=%: %',
            SQLSTATE,
            SQLERRM;
        RAISE EXCEPTION
            'LT500: Unexpected database error while assigning the prerequisite: %',
            SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

-- ============================================================
-- 2. Remove one prerequisite
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_remove_course_prerequisite(
    p_actor_id BIGINT,
    p_course_id BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS TABLE (
    course_id BIGINT,
    prerequisite_course_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_course_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM public.courses c
            WHERE c.id = p_course_id
       )
    THEN
        RAISE EXCEPTION
            'LTP01: Course % does not exist.',
            p_course_id
            USING ERRCODE = 'LTP01';
    END IF;
    PERFORM public.fn_require_course_manager(
        p_course_id,
        p_actor_id
    );
    IF NOT public.fn_course_is_editable(
        p_course_id
    )
    THEN
        RAISE EXCEPTION
            'LTC12: Prerequisites can only be edited while the course is draft or rejected.'
            USING ERRCODE = 'LTC12';
    END IF;
    DELETE FROM public.course_prerequisites cp
    WHERE cp.course_id =
          p_course_id
      AND cp.prerequisite_course_id =
          p_prerequisite_course_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION
            'LTP03: Prerequisite relation for course % on course % does not exist.',
            p_prerequisite_course_id,
            p_course_id
            USING ERRCODE = 'LTP03';
    END IF;
    course_id :=
        p_course_id;
    prerequisite_course_id :=
        p_prerequisite_course_id;
    RETURN NEXT;
    RETURN;
EXCEPTION
    WHEN OTHERS THEN

        IF SQLSTATE IN (
            'LTP01',
            'LTP03',
            'LTC10',
            'LTC12'
        )
        THEN
            RAISE;
        END IF;
        RAISE LOG
            'sp_remove_course_prerequisite unexpected sqlstate=%: %',
            SQLSTATE,
            SQLERRM;
        RAISE EXCEPTION
            'LT500: Unexpected database error while removing the prerequisite: %',
            SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;

-- ============================================================
-- 3. Atomically replace the complete prerequisite definition
-- ============================================================

CREATE OR REPLACE FUNCTION public.sp_replace_course_prerequisites(
    p_actor_id BIGINT,
    p_course_id BIGINT,
    p_prerequisites JSONB
)
RETURNS TABLE (
    target_course_id BIGINT,
    target_title VARCHAR,
    target_slug VARCHAR,
    target_status TEXT,
    editable BOOLEAN,
    prerequisites JSONB,
    candidates JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_payload JSONB;
    v_item JSONB;
    v_prerequisite_id_numeric NUMERIC;
    v_prerequisite_course_id BIGINT;
    v_score_raw NUMERIC;
    v_score NUMERIC(5,2);
    v_seen_ids BIGINT[] :=
        ARRAY[]::BIGINT[];
BEGIN
    IF p_course_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM public.courses c
            WHERE c.id = p_course_id
       )
    THEN
        RAISE EXCEPTION
            'LTP01: Course % does not exist.',
            p_course_id
            USING ERRCODE = 'LTP01';
    END IF;
    PERFORM public.fn_require_course_manager(
        p_course_id,
        p_actor_id
    );
    IF NOT public.fn_course_is_editable(
        p_course_id
    )
    THEN
        RAISE EXCEPTION
            'LTC12: Prerequisites can only be edited while the course is draft or rejected.'
            USING ERRCODE = 'LTC12';
    END IF;
    v_payload :=
        COALESCE(
            p_prerequisites,
            '[]'::JSONB
        );
    IF jsonb_typeof(v_payload) <>
       'array'
    THEN
        RAISE EXCEPTION
            'LTP05: prerequisites must be a JSON array.'
            USING ERRCODE = 'LTP05';
    END IF;
    FOR v_item IN

        SELECT value
        FROM jsonb_array_elements(v_payload)
    LOOP
        IF jsonb_typeof(v_item) <>
           'object'
        THEN
            RAISE EXCEPTION
                'LTP05: Every prerequisite entry must be an object.'
                USING ERRCODE = 'LTP05';
        END IF;
        IF NOT (
            v_item ?
            'prerequisiteCourseId'
        )
        OR jsonb_typeof(
            v_item ->
            'prerequisiteCourseId'
        ) <> 'number'
        THEN
            RAISE EXCEPTION
                'LTP05: Every prerequisite requires a numeric prerequisiteCourseId.'
                USING ERRCODE = 'LTP05';
        END IF;
        v_prerequisite_id_numeric :=
            (
                v_item ->
                'prerequisiteCourseId'
            )::TEXT::NUMERIC;
        IF v_prerequisite_id_numeric < 1
           OR v_prerequisite_id_numeric >
              9223372036854775807::NUMERIC

           OR v_prerequisite_id_numeric <>
              TRUNC(
                  v_prerequisite_id_numeric
              )
        THEN
            RAISE EXCEPTION
                'LTP05: prerequisiteCourseId must be a positive integer.'
                USING ERRCODE = 'LTP05';
        END IF;
        v_prerequisite_course_id :=
            v_prerequisite_id_numeric::BIGINT;
        IF v_prerequisite_course_id =
           ANY(v_seen_ids)
        THEN

            RAISE EXCEPTION
                'LTP05: Course % appears more than once in the prerequisite list.',
                v_prerequisite_course_id
                USING ERRCODE = 'LTP05';

        END IF;
        v_seen_ids :=
            array_append(
                v_seen_ids,
                v_prerequisite_course_id
            );
        IF v_prerequisite_course_id =
           p_course_id
        THEN

            RAISE EXCEPTION
                'LTP02: A course cannot be its own prerequisite.'
                USING ERRCODE = 'LTP02';
        END IF;
        IF NOT (
            v_item ?
            'requiredMinScore'
        )
        OR jsonb_typeof(
            v_item ->
            'requiredMinScore'
        ) = 'null'
        THEN
            v_score_raw :=
                60.00;
        ELSIF jsonb_typeof(
            v_item ->
            'requiredMinScore'
        ) <> 'number'
        THEN
            RAISE EXCEPTION
                'LTP05: requiredMinScore must be numeric.'
                USING ERRCODE = 'LTP05';
        ELSE
            v_score_raw :=
                (
                    v_item ->
                    'requiredMinScore'
                )::TEXT::NUMERIC;

        END IF;
        IF v_score_raw < 0
           OR v_score_raw > 100
        THEN
            RAISE EXCEPTION
                'LTP05: requiredMinScore must be between 0 and 100.'
                USING ERRCODE = 'LTP05';
        END IF;
        IF v_score_raw <>
           ROUND(
               v_score_raw,
               2
           )
        THEN
            RAISE EXCEPTION
                'LTP05: requiredMinScore cannot contain more than 2 decimal places.'
                USING ERRCODE = 'LTP05';
        END IF;
        IF NOT public.fn_prerequisite_candidate_is_selectable(
            p_actor_id,
            p_course_id,
            v_prerequisite_course_id
        )
        THEN
            RAISE EXCEPTION
                'LTP05: Course % is not available as a prerequisite.',
                v_prerequisite_course_id
                USING ERRCODE = 'LTP05';
        END IF;
    END LOOP;
    DELETE FROM public.course_prerequisites cp
    WHERE cp.course_id =
          p_course_id;
    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(v_payload)
    LOOP
        v_prerequisite_course_id :=
            (
                (
                    v_item ->
                    'prerequisiteCourseId'
                )::TEXT::NUMERIC
            )::BIGINT;
        IF NOT (
            v_item ?
            'requiredMinScore'
        )
        OR jsonb_typeof(
            v_item ->
            'requiredMinScore'
        ) = 'null'
        THEN
            v_score :=
                60.00;
        ELSE
            v_score :=
                (
                    v_item ->
                    'requiredMinScore'
                )::TEXT::NUMERIC;

        END IF;
        INSERT INTO public.course_prerequisites (
            course_id,
            prerequisite_course_id,
            required_min_score
        )
        VALUES (
            p_course_id,
            v_prerequisite_course_id,
            v_score
        );
    END LOOP;
    RETURN QUERY
    SELECT *
    FROM public.fn_prerequisite_editor(
        p_actor_id,
        p_course_id
    );
    RETURN;
EXCEPTION
    WHEN OTHERS THEN

        IF SQLSTATE IN (
            'LTP01',
            'LTP02',
            'LTP03',
            'LTP04',
            'LTP05',
            'LTC10',
            'LTC12',
            '23503',
            '23505'
        )
        THEN
            RAISE;
        END IF;
        RAISE LOG
            'sp_replace_course_prerequisites unexpected sqlstate=%: %',
            SQLSTATE,
            SQLERRM;
        RAISE EXCEPTION
            'LT500: Unexpected database error while replacing prerequisites: %',
            SQLERRM
            USING ERRCODE = 'LT500';
END;
$$;