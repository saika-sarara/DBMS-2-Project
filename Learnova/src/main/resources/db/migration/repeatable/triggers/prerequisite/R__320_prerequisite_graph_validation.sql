-- ============================================================
-- Learnova
-- Current prerequisite graph validation
--
-- Owns:
--   * self-reference prevention
--   * circular dependency prevention
--   * maximum prerequisite-chain depth = 5
--
-- The graph is validated before an INSERT/UPDATE becomes visible.
-- ============================================================

-- ============================================================
-- 1. Validate a proposed prerequisite edge
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_validate_prerequisite_edge(
    p_old_course_id BIGINT,
    p_old_prerequisite_course_id BIGINT,
    p_course_id BIGINT,
    p_prerequisite_course_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_has_cycle BOOLEAN;
    v_too_deep BOOLEAN;
BEGIN
    IF p_course_id =
       p_prerequisite_course_id
    THEN

        RAISE EXCEPTION
            'LTP02: A course cannot be its own prerequisite.'
            USING ERRCODE = 'LTP02';
    END IF;
    WITH RECURSIVE
    edges AS (
        SELECT
            cp.course_id,
            cp.prerequisite_course_id
        FROM public.course_prerequisites cp
        WHERE NOT (
            p_old_course_id IS NOT NULL
            AND cp.course_id =
                p_old_course_id
            AND cp.prerequisite_course_id =
                p_old_prerequisite_course_id
        )
        UNION
        SELECT
            p_course_id,
            p_prerequisite_course_id
    ),
    graph_walk AS (
        SELECT
            e.course_id AS root_course_id,
            e.prerequisite_course_id
                AS current_course_id,
            1 AS depth,
            ARRAY[
                e.course_id,
                e.prerequisite_course_id
            ]::BIGINT[] AS path,
            FALSE AS cycle
        FROM edges e
        UNION ALL
        SELECT
            walk.root_course_id,
            next_edge.prerequisite_course_id,
            walk.depth + 1,
            walk.path ||
                next_edge.prerequisite_course_id,
            next_edge.prerequisite_course_id =
                ANY(walk.path)
        FROM graph_walk walk
        JOIN edges next_edge
          ON next_edge.course_id =
             walk.current_course_id
        WHERE NOT walk.cycle
    )
    SELECT
        COALESCE(
            BOOL_OR(walk.cycle),
            FALSE
        ),
        COALESCE(
            BOOL_OR(walk.depth > 5),
            FALSE
        )
    INTO
        v_has_cycle,
        v_too_deep
    FROM graph_walk walk;
    IF v_has_cycle THEN
        RAISE EXCEPTION
            'LTP02: Adding this prerequisite would create a circular dependency.'
            USING ERRCODE = 'LTP02';
    END IF;
    IF v_too_deep THEN
        RAISE EXCEPTION
            'LTP04: Prerequisite chains cannot exceed 5 levels.'
            USING ERRCODE = 'LTP04';
    END IF;
END;
$$;

-- ============================================================
-- 2. Trigger wrapper
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_prevent_circular_prerequisite()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM public.fn_validate_prerequisite_edge(
            OLD.course_id,
            OLD.prerequisite_course_id,
            NEW.course_id,
            NEW.prerequisite_course_id
        );
    ELSE
        PERFORM public.fn_validate_prerequisite_edge(
            NULL,
            NULL,
            NEW.course_id,
            NEW.prerequisite_course_id
        );
    END IF;
    RETURN NEW;
END;
$$;

-- ============================================================
-- 3. Current graph-validation trigger
-- ============================================================

DROP TRIGGER IF EXISTS
    trg_prevent_circular_prerequisite
ON public.course_prerequisites;
CREATE TRIGGER
    trg_prevent_circular_prerequisite
BEFORE INSERT
OR UPDATE OF
    course_id,
    prerequisite_course_id
ON public.course_prerequisites
FOR EACH ROW
EXECUTE FUNCTION
    public.fn_prevent_circular_prerequisite();