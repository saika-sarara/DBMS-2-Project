/* ==========================================================================
   Learnova Shared Constants (window.LearnovaConstants)
   Single source of truth for API routes, roles, storage keys, and quiz rules.
   ========================================================================== */

window.LearnovaConstants = {
    /* Backend API base. The Spring Boot app maps the enrollment module at
       /api/v1/enrollments (see EnrollmentController), so the client base must
       end in /api/v1 for real requests to reach the backend. The port must
       match the backend's server.port (PORT env var, see .env — default 8000). */
    API_BASE_URL: 'http://localhost:8000/api/v1',

    /* Backend REST contract for the enrollment module. Paths are relative to
       API_BASE_URL. The database owns every enrollment rule and exception
       (LTU01/LTC01/LTT01/LTN01/LTN02/LTC02/LTP01/LT500); this client only
       mirrors the routes and forwards the database message verbatim. */
    ENROLLMENT_ROUTES: {
        ENROLL_COURSE: '/enrollments/courses/:courseId',
        ENROLL_TRACK: '/enrollments/tracks/:trackId',
        MY_COURSES: '/enrollments/my-courses',
        MY_TRACKS: '/enrollments/my-tracks',
        COURSE_ACCESS: '/enrollments/courses/:courseId/access',
        STATS: '/enrollments/stats'
    },

    ROLES: {
        STUDENT: 'Student',
        INSTRUCTOR: 'Instructor',
        ADMIN: 'Admin'
    },

    /* Account statuses (spec 1.1): suspended / banned users cannot log in */
    ACCOUNT_STATUS: {
        ACTIVE: 'active',
        SUSPENDED: 'suspended',
        BANNED: 'banned'
    },

    /* Course lifecycle (spec 2.2): draft -> pending_review -> published,
       with rejected and archived terminal states. Mirrors the database
       chk_courses_status CHECK constraint exactly. */
    COURSE_STATUS: {
        DRAFT: 'draft',
        PENDING_REVIEW: 'pending_review',
        PUBLISHED: 'published',
        REJECTED: 'rejected',
        ARCHIVED: 'archived',
        /* Legacy alias so pre-existing pages keep resolving the pending
           state to the real database value. */
        PENDING: 'pending_review'
    },

    /* Catalogue search/sort options backed by fn_search_course_catalogue */
    COURSE_SORT_OPTIONS: {
        RELEVANCE: 'relevance',
        RATING: 'rating',
        NEWEST: 'newest',
        TITLE: 'title'
    },

    COURSE_DIFFICULTIES: [
        'beginner',
        'intermediate',
        'advanced'
    ],

    /* Default catalogue paging limits (DEFAULT_PAGE_SIZE / MAX_PAGE_SIZE) */
    CATALOGUE_PAGE_SIZE: 12,
    CATALOGUE_MAX_PAGE_SIZE: 50,

    /* Instructor request states (spec 1.3) */
    INSTRUCTOR_REQUEST_STATUS: {
        PENDING: 'pending',
        APPROVED: 'approved',
        REJECTED: 'rejected'
    },

    /* Grading rules (spec 3.3 / 5.3): pass >= 60%, 3 attempts per day,
       reset at 00:00 midnight */
    GRADING: {
        PASSING_SCORE: 60,
        DAILY_QUIZ_ATTEMPTS: 3,
        DAILY_BYPASS_ATTEMPTS: 3
    },

    /* Certificates (spec 8.2): unique code format LRV-XXXX-XXXX */
    CERTIFICATE: {
        CODE_PREFIX: 'LRV',
        SEGMENTS: 2,
        SEGMENT_LENGTH: 4
    },

    /* localStorage keys for the session, mock registry, and demo flows */
    SESSION_KEY: 'learnova_session',
    USERS_KEY: 'learnova_users',
    INSTRUCTOR_REQUEST_KEY: 'learnova_instructor_requests',
    NOTIFICATIONS_KEY: 'learnova_notifications',
    PROGRESS_KEY: 'learnova_progress',
    COURSES_KEY: 'learnova_courses',

    /* Default course track names offered by the platform */
    TRACKS: ['Database Engineer', 'Frontend Dev', 'Data Science'],

    /* Product rule: instructors bank 20 MCQs per lesson, students see 5 random */
    QUIZ_DEFAULTS: {
        BANK_SIZE: 20,
        RANDOM_PER_STUDENT: 5
    }
};
