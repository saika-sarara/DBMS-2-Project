-- Ordered dependencies for the SQL Learning Path.
-- Basic SQL has no prerequisite; each subsequent course requires successful
-- completion of the foundation courses before enrollment is allowed.
INSERT INTO public.course_prerequisites (
    course_id,
    prerequisite_course_id,
    required_min_score
)
SELECT
    target_course.id,
    prerequisite_course.id,
    60.00
FROM (VALUES
    ('intermediate-sql', 'basic-sql'),
    ('advanced-sql',     'basic-sql'),
    ('advanced-sql',     'intermediate-sql')
) AS dependency(target_slug, prerequisite_slug)
JOIN public.courses target_course
    ON target_course.slug = dependency.target_slug
JOIN public.courses prerequisite_course
    ON prerequisite_course.slug = dependency.prerequisite_slug
ON CONFLICT (course_id, prerequisite_course_id) DO NOTHING;
