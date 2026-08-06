-- =========================================================
-- fn_admin_enrollment_stats
--
-- FUNCTION for the enrollment feature.
-- Source of truth: enrollment.sql (V6). This file is a
-- per-object reference view of the same schema.
-- =========================================================
-- 7. Reporting
-- NOTE: vw_course_prerequisite_closure is NOT defined here. It is a
-- recursive-CTE view over the prerequisite module's course_prerequisites
-- table and belongs to that module.

CREATE OR REPLACE FUNCTION public.fn_admin_enrollment_stats()
RETURNS TABLE (
    total_users           BIGINT,
    active_students       BIGINT,
    total_courses         BIGINT,
    published_courses     BIGINT,
    total_enrollments     BIGINT,
    active_enrollments    BIGINT,
    completed_enrollments BIGINT,
    distinct_students     BIGINT
)
LANGUAGE sql
AS $$
    SELECT
        (SELECT COUNT(*) FROM public.users),
        (SELECT COUNT(DISTINCT u.id)
           FROM public.users u
           JOIN public.user_roles ur ON ur.user_id = u.id
           JOIN public.roles r ON r.id = ur.role_id
          WHERE u.account_status = 'ACTIVE'
            AND r.name = 'STUDENT'),
        (SELECT COUNT(*) FROM public.courses),
        (SELECT COUNT(*) FROM public.courses WHERE status = 'PUBLISHED'),
        (SELECT COUNT(*) FROM public.enrollments),
        (SELECT COUNT(*) FROM public.enrollments WHERE status = 'active'),
        (SELECT COUNT(*) FROM public.enrollments WHERE status = 'completed'),
        (SELECT COUNT(DISTINCT user_id) FROM public.enrollments);
$$;
