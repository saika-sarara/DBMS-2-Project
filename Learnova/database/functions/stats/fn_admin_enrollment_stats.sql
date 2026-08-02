-- =========================================================
-- fn_admin_enrollment_stats
--
-- Fresh (non-cached) platform-wide counters for the admin
-- dashboard. Read directly from the base tables, so it is
-- always current; no warehouse or ETL is involved.
--
-- active_students counts users whose account is ACTIVE and who
-- hold the STUDENT role (an active INSTRUCTOR is not a student).
-- =========================================================

CREATE OR REPLACE FUNCTION fn_admin_enrollment_stats()
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
        (SELECT COUNT(*) FROM users),
        (SELECT COUNT(DISTINCT u.id)
           FROM users u
           JOIN user_roles ur ON ur.user_id = u.id
           JOIN roles r ON r.id = ur.role_id
          WHERE u.account_status = 'ACTIVE'
            AND r.name = 'STUDENT'),
        (SELECT COUNT(*) FROM courses),
        (SELECT COUNT(*) FROM courses WHERE status = 'PUBLISHED'),
        (SELECT COUNT(*) FROM enrollments),
        (SELECT COUNT(*) FROM enrollments WHERE status = 'active'),
        (SELECT COUNT(*) FROM enrollments WHERE status = 'completed'),
        (SELECT COUNT(DISTINCT user_id) FROM enrollments);
$$;
