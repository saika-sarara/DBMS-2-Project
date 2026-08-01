/* ==========================================================================
   Learnova Shared Constants (window.LearnovaConstants)
   Single source of truth for API routes, roles, storage keys, and quiz rules.
   ========================================================================== */

window.LearnovaConstants = {
    API_BASE_URL: 'http://localhost:8000/api',

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

    /* Course lifecycle (spec 2.2): draft -> pending -> published */
    COURSE_STATUS: {
        DRAFT: 'draft',
        PENDING: 'pending',
        PUBLISHED: 'published'
    },

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
