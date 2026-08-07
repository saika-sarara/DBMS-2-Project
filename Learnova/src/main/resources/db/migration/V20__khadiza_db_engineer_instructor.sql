-- =========================================================
-- V20: Khadiza Sultana owns the Database Engineer track
--
-- The Database Engineer track (courses 1-3), its prerequisites
-- (2 requires 1; 3 requires 2) and the demo track enrollment for
-- Khadiza Sultana were seeded by V8 / V9 / V19. V17 had moved the
-- six demo courses to two instructor accounts, which left the
-- Database Engineer track owned by an instructor (Rafi Ahmed)
-- instead of the demo admin. This migration restores the intended
-- demo ownership so the track is demoed under Khadiza Sultana as
-- the instructor:
--
--   * grants Khadiza Sultana (sultanakhadiza37@gmail.com) the
--     INSTRUCTOR role (she already has ADMIN + STUDENT)
--   * re-assigns the three Database Engineer track courses
--     (1-3) to her
--   * enrolls the two demo students (Maliha Tasnim and Saika
--     Sarara) in the Database Engineer track so the student
--     dashboards start with real data
--
-- Idempotent: role grants use ON CONFLICT, course ownership is a
-- keyed UPDATE, and track enrollment skips existing enrollments.
-- =========================================================

-- =========================================================
-- 1. Khadiza Sultana becomes an instructor too
-- =========================================================

INSERT INTO public.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM public.users u
JOIN public.roles r ON r.name = 'INSTRUCTOR'
WHERE u.email = 'sultanakhadiza37@gmail.com'
ON CONFLICT DO NOTHING;

-- =========================================================
-- 2. Re-assign the Database Engineer track courses to her
-- (courses 1-3 are exactly the track_courses of the Database
-- Engineer track, but keying on the track membership keeps this
-- correct even if course ids shift)
-- =========================================================

UPDATE public.courses c
SET instructor_id = (
    SELECT u.id FROM public.users u
    WHERE u.email = 'sultanakhadiza37@gmail.com'
)
WHERE c.id IN (
    SELECT tc.course_id
    FROM public.track_courses tc
    JOIN public.tracks t ON t.id = tc.track_id
    WHERE t.title = 'Database Engineer'
);

-- =========================================================
-- 3. Enroll the demo students in the Database Engineer track
-- (the AFTER INSERT trigger auto-enrolls the published track
-- courses with source = 'track')
-- =========================================================

SELECT public.sp_enroll_track(u.id, t.id)
FROM public.users u
CROSS JOIN public.tracks t
WHERE u.email IN ('malihatasnim@gmail.com', 'saikasarara@gmail.com')
  AND t.title = 'Database Engineer'
  AND NOT EXISTS (
      SELECT 1
      FROM public.track_enrollments te
      WHERE te.user_id = u.id
        AND te.track_id = t.id
  );

-- =========================================================
-- 4. Re-align identity sequences (sp_enroll_track inserted rows)
-- =========================================================

SELECT setval(
    pg_get_serial_sequence('public.enrollments', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.enrollments)
);

SELECT setval(
    pg_get_serial_sequence('public.track_enrollments', 'id'),
    (SELECT COALESCE(MAX(id), 1) FROM public.track_enrollments)
);
