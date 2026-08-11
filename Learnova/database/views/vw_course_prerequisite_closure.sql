-- =========================================================
-- vw_course_prerequisite_closure
--
-- VIEW for the prerequisite feature.
-- Source of truth: prerequisite.sql (V9). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 4. Dependency view (recursive CTE)
-- For every course, every course it transitively requires (directly or
-- through a chain) together with the dependency depth. A row
-- (course_id=3, required_course_id=1, depth=2) reads as "course 3
-- cannot be enrolled until course 1 is completed, because course 3
-- requires course 2 which requires course 1."

CREATE OR REPLACE VIEW public.vw_course_prerequisite_closure AS
WITH RECURSIVE prereq_chain AS (
    SELECT cp.course_id,
           cp.prerequisite_course_id AS required_course_id,
           1                          AS depth
    FROM public.course_prerequisites cp

    UNION ALL

    SELECT pc.course_id,
           cp.prerequisite_course_id,
           pc.depth + 1
    FROM prereq_chain pc
    JOIN public.course_prerequisites cp
      ON cp.course_id = pc.required_course_id
)
SELECT pc.course_id,
       c.title AS course_title,
       pc.required_course_id,
       r.title AS required_course_title,
       pc.depth
FROM prereq_chain pc
JOIN public.courses c ON c.id = pc.course_id
JOIN public.courses r ON r.id = pc.required_course_id;
