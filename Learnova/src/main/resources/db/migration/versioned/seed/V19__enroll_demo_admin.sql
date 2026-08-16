-- =========================================================
-- V19: Enroll the demo admin in the Database Engineer track
--
-- The Database Engineer track, its courses and the prerequisite
-- chain (2 requires 1; 3 requires 2) were seeded by V8 / V9. This
-- migration adds the missing enrollment layer so the student-facing
-- flows can be demoed with the admin account:
--
--   * grants the STUDENT role to the demo admin
--     (sultanakhadiza37@gmail.com) because the enrollment engine
--     only accepts active students
--   * enrolls that account in the "Database Engineer" track via
--     sp_enroll_track, which auto-enrolls every published track
--     course (source = 'track', so prerequisites are not enforced
--     at enroll time -- they gate content access instead)
--
-- Idempotent: the role insert is guarded by ON CONFLICT and the
-- track enrollment is skipped when one already exists.
-- =========================================================

-- =========================================================
-- 1. Make the demo admin an active student too
-- =========================================================

INSERT INTO public.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM public.users u
JOIN public.roles r ON r.name = 'STUDENT'
WHERE u.email = 'sultanakhadiza37@gmail.com'
ON CONFLICT DO NOTHING;

-- =========================================================
-- 2. Enroll in the Database Engineer track
-- (the AFTER INSERT trigger auto-enrolls the published courses)
-- =========================================================

SELECT public.sp_enroll_track(u.id, t.id)
FROM public.users u
CROSS JOIN public.tracks t
WHERE u.email = 'sultanakhadiza37@gmail.com'
  AND t.title = 'Database Engineer'
  AND NOT EXISTS (
      SELECT 1
      FROM public.track_enrollments te
      WHERE te.user_id = u.id
        AND te.track_id = t.id
  );

-- =========================================================
-- 3. Re-align identity sequences (sp_enroll_track inserted rows)
-- =========================================================

SELECT setval(
    pg_get_serial_sequence('public.enrollments', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.enrollments)
);

SELECT setval(
    pg_get_serial_sequence('public.track_enrollments', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.track_enrollments)
);
