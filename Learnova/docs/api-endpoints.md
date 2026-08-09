# Learnova API Endpoints

Base URL: `http://localhost:{PORT}/api/v1` (port = `PORT` env var; default `8000`,
`8080` in the current dev environment).
Docs: live OpenAPI at `/v3/api-docs`, Swagger UI at `/swagger-ui/index.html`.

## Conventions

- **Auth**: all endpoints except `/auth/register` and `/auth/login` require
  `Authorization: Bearer <token>` (stateless HS256 JWT).
- **Envelope** — every response is an `ApiResponse`:

```json
{
  "success": true,
  "message": "Success",
  "data": { },
  "timestamp": "2026-08-02T15:43:23Z"
}
```

- **Errors** use the same envelope with `success: false` and `data: null`.
- **Roles** (from JWT): `ROLE_STUDENT`, `ROLE_INSTRUCTOR`, `ROLE_ADMIN`.

## Access Matrix

| Path | Public | Student | Instructor | Admin |
|---|:-:|:-:|:-:|:-:|
| `POST /auth/register` | ✅ | — | — | — |
| `POST /auth/login` | ✅ | — | — | — |
| `GET /auth/me` | — | ✅ | ✅ | ✅ |
| `POST /enrollments/courses/{id}` | — | ✅ | ❌ | ❌ |
| `POST /enrollments/tracks/{id}` | — | ✅ | ❌ | ❌ |
| `GET /enrollments/my-courses` | — | ✅ | ❌ | ❌ |
| `GET /enrollments/my-tracks` | — | ✅ | ❌ | ❌ |
| `GET /enrollments/courses/{id}/access` | — | ✅ | ❌ | ❌ |
| `GET /enrollments/stats` | — | ❌ | ❌ | ✅ |

## Status Codes

| Code | Meaning |
|---|---|
| `200` | Success |
| `400` | Domain/validation error (enrollment `LTxxx` codes) |
| `401` | Missing/invalid/expired token; wrong credentials |
| `403` | Suspended/banned account; authenticated but role not allowed |
| `500` | Unexpected error |

---

## Authentication

### `POST /auth/register`

Creates a student account (bcrypt-hashed password, `STUDENT` role).

Request:
```json
{ "firstName": "Jane", "lastName": "Doe", "email": "jane@example.com", "password": "Secret123!" }
```
(`name` or `fullName` may be supplied instead of `firstName`/`lastName`.)

Response `200`:
```json
{ "success": true, "message": "User registered successfully.", "data": null, "timestamp": "..." }
```

Errors:
- `400` — `"Email is already in use."`

### `POST /auth/login`

Request:
```json
{ "email": "malihatasnim@gmail.com", "password": "password123" }
```

Response `200`:
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "id": 9,
    "token": "<jwt>",
    "email": "malihatasnim@gmail.com",
    "name": "Maliha Tasnim",
    "fullName": "Maliha Tasnim",
    "roles": ["Student"],
    "role": "Student",
    "primaryRole": "Student",
    "status": "active"
  }
}
```

Errors:
- `401` — `"Invalid email or password."`
- `403` — `"This account is suspended. Please contact support."` / `"This account is banned. Please contact support."`

### `GET /auth/me`

Requires Bearer token. Returns the current user's profile.

Response `200`:
```json
{
  "success": true,
  "message": "Success",
  "data": {
    "id": 9,
    "email": "malihatasnim@gmail.com",
    "fullName": "Maliha Tasnim",
    "roles": ["Student"],
    "role": "Student",
    "status": "active"
  }
}
```

Errors: `401` — `"Authentication is required."`

---

## Enrollment

### `POST /enrollments/courses/{courseId}`

Enroll the authenticated student in a course (`source = standalone`).

Response `200`:
```json
{
  "success": true,
  "message": "Enrollment successful",
  "data": {
    "enrollmentId": 12,
    "entityId": 2,
    "entityTitle": "SQL & Query Optimization",
    "entityType": "course",
    "status": "active",
    "progressPct": 0.00,
    "source": "standalone",
    "enrolledAt": "2026-08-02T15:43:23Z",
    "completedAt": null,
    "alreadyEnrolled": false
  }
}
```

Errors (`400`, database message forwarded verbatim):
- `LTU01` — not an active student.
- `LTC01` — course does not exist or is not published.
- `LTN01` — already enrolled (active).
- `LTC02` — already completed; cannot re-enroll.
- `LTP01` — prerequisites not satisfied.

### `POST /enrollments/tracks/{trackId}`

Enroll in a track; auto-enrolls its published courses (`source = track`).

Response `200`:
```json
{
  "success": true,
  "message": "Enrollment successful",
  "data": {
    "enrollmentId": 5,
    "entityId": 1,
    "entityTitle": "Database Engineer",
    "entityType": "track",
    "status": "active",
    "progressPct": 0.00,
    "source": "track",
    "enrolledAt": "2026-08-02T15:43:23Z",
    "completedAt": null,
    "alreadyEnrolled": false
  }
}
```

Errors (`400`): `LTU01`, `LTT01` (track missing/not published), `LTN02` (already in track).

### `GET /enrollments/my-courses`

Returns the authenticated student's course enrollments.

Response `200`: `data` is an array of `EnrollmentResponse` objects with
`entityType: "course"`.

### `GET /enrollments/my-tracks`

Returns the authenticated student's track enrollments (`entityType: "track"`).

### `GET /enrollments/courses/{courseId}/access`

Access decision for the authenticated student on a course.

Response `200`:
```json
{
  "success": true,
  "message": "Success",
  "data": {
    "courseId": 2,
    "accessible": true,
    "reasonCode": "active",
    "reason": "Course is accessible.",
    "enrollmentStatus": "active",
    "progressPct": 0.00,
    "blockingCourseId": null,
    "blockingCourseTitle": null
  }
}
```

`reasonCode` values: `course_not_found`, `course_not_published`, `not_enrolled`,
`completed`, `active`, `prerequisites_locked`.

### `GET /enrollments/stats`

**Admin only.** Platform-wide counters from `fn_admin_enrollment_stats()`.

Response `200`:
```json
{
  "success": true,
  "message": "Success",
  "data": {
    "totalUsers": 10,
    "activeStudents": 6,
    "totalCourses": 6,
    "publishedCourses": 4,
    "totalEnrollments": 6,
    "activeEnrollments": 5,
    "completedEnrollments": 1,
    "distinctStudents": 3
  }
}
```

Errors:
- `403` — `"You do not have permission to access this resource."` (non-admin)
- `401` — no/invalid token.

---

## Final Assessment Endpoints

Instructor endpoints:

- PUT /api/v1/instructor/courses/{courseId}/final-assessment
  - Create or update the course final assessment settings (title, passingScore, dailyAttemptLimit, isActive).

- GET /api/v1/instructor/courses/{courseId}/final-assessment
  - Read assessment configuration and question bank (instructor-only; may include correct answers).

- POST /api/v1/instructor/final-assessments/{assessmentId}/questions
  - Add a question with options and exactly one correct option.

- PUT /api/v1/instructor/questions/{questionId}
  - Update a question and its options (instructor-only).

- DELETE /api/v1/instructor/questions/{questionId}
  - Delete a question (instructor-only).

- GET /api/v1/instructor/final-assessments/{assessmentId}/questions
  - Instructor question-bank view including correct answer metadata.

Student endpoints:

- GET /api/v1/student/courses/{courseId}/final-assessment/status
  - Returns contentComplete, eligible, alreadyPassed, questionCount, questionsPerAttempt (10), passingScore, attemptsToday, remainingAttempts.

- POST /api/v1/student/courses/{courseId}/final-assessment/attempts
  - Start a new attempt. Server verifies enrollment, content progress and snapshots 10 random questions and option order.

- GET /api/v1/student/final-assessment/attempts/{attemptId}
  - Retrieve an existing attempt (returns persisted question and option order; student view hides correct answers).

- PUT /api/v1/student/final-assessment/attempts/{attemptId}/answers/{questionId}
  - Save or update the selected option for a question in an in-progress attempt.

- POST /api/v1/student/final-assessment/attempts/{attemptId}/submit
  - Submit and grade the attempt. Server-side grading only, updates enrollment status on pass.

- GET /api/v1/student/courses/{courseId}/final-assessment/history
  - Returns the authenticated student's submission history for the course.


## Related Docs

- Live spec: `GET /v3/api-docs` · Swagger UI: `GET /swagger-ui/index.html`
- Database design: `docs/database-design/auth.md`, `course.md`, `enrollment.md`,
  `prerequisite.md`, `progress.md`, `indexes-views.md`
