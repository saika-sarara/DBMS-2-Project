-- =========================================================
-- vw_course_prerequisite_closure
--
-- Recursive CTE over course_prerequisites: for every course,
-- every course it transitively requires (directly or through a
-- chain of prerequisites) together with the dependency depth.
--
-- A row (course_id=3, required_course_id=1, depth=2) reads as
-- "course 3 cannot be enrolled until course 1 is completed,
-- because course 3 requires course 2 which requires course 1."
--
-- Enables questions like "if I complete this course, which
-- other courses unlock?" without knowing the chain length.
-- =========================================================

CREATE OR REPLACE VIEW vw_course_prerequisite_closure AS
WITH RECURSIVE prereq_chain AS (
    SELECT cp.course_id,
           cp.prerequisite_course_id AS required_course_id,
           1                          AS depth
    FROM course_prerequisites cp

    UNION ALL

    SELECT pc.course_id,
           cp.prerequisite_course_id,
           pc.depth + 1
    FROM prereq_chain pc
    JOIN course_prerequisites cp
      ON cp.course_id = pc.required_course_id
)
SELECT pc.course_id,
       c.title AS course_title,
       pc.required_course_id,
       r.title AS required_course_title,
       pc.depth
FROM prereq_chain pc
JOIN courses c ON c.id = pc.course_id
JOIN courses r ON r.id = pc.required_course_id;
