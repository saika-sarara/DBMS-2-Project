# Enrollment Module — Database Architecture

Status: **Implemented** (migration `V6`; design file `database/enrollment.sql`).
Owned by: `EnrollmentController`, `EnrollmentService`, `EnrollmentRepository`,
`EnrollmentCommandRepository`. All business rules and exception codes live in the
database; the Java layer only forwards the database message verbatim.

## Tables

| Table | Purpose |
|---|---|
| `enrollments` | One row per (student, course) enrollment. |
| `track_enrollments` | One row per (student, track) enrollment. |
| `lesson_progress` | Per-lesson state for each course enrollment. |

### `enrollments`
- `UNIQUE (user_id, course_id)` — a student can enroll in a course once.
- `status` — `active` or `completed` (`chk_enrollments_status`).
- `source` — `standalone` or `track` (`chk_enrollments_source`); track-source rows are
  created by the auto-enroll trigger and cannot be duplicated by a standalone enroll.
- `progress_pct` — `NUMERIC(5,2)` in `[0, 100]` (`chk_enrollments_progress_range`).
- `final_score_pct`, `completed_at` filled when the course is completed.

### `track_enrollments`
- `UNIQUE (user_id, track_id)`; same status/progress rules as `enrollments`.

### `lesson_progress`
- `UNIQUE (enrollment_id, lesson_id)`; FKs cascade on delete.
- `status` — `locked`, `unlocked`, or `completed` (`chk_lesson_progress_status`).
- Rows are auto-created (`locked`) when a course enrollment is inserted.

## ER Diagram

```mermaid
erDiagram
    USERS {
        bigint id PK
    }
    COURSES {
        bigint id PK
        varchar status
    }
    LESSONS {
        bigint id PK
        bigint course_id FK
        int sequence_order
    }
    TRACKS {
        bigint id PK
        varchar status
    }
    TRACK_COURSES {
        bigint track_id PK,FK
        bigint course_id PK,FK
        int sequence_order
    }
    ENROLLMENTS {
        bigint id PK
        bigint user_id FK
        bigint course_id FK
        varchar status
        numeric progress_pct
        numeric final_score_pct
        varchar source
        timestamptz enrolled_at
        timestamptz completed_at
    }
    TRACK_ENROLLMENTS {
        bigint id PK
        bigint user_id FK
        bigint track_id FK
        varchar status
        numeric progress_pct
        timestamptz enrolled_at
        timestamptz completed_at
    }
    LESSON_PROGRESS {
        bigint id PK
        bigint enrollment_id FK
        bigint lesson_id FK
        varchar status
        timestamptz unlocked_at
        timestamptz completed_at
    }

    USERS ||--o{ ENROLLMENTS : "enrolls in"
    COURSES ||--o{ ENROLLMENTS : "enrolled by"
    USERS ||--o{ TRACK_ENROLLMENTS : "enrolls in"
    TRACKS ||--o{ TRACK_ENROLLMENTS : "enrolled by"
    ENROLLMENTS ||--o{ LESSON_PROGRESS : "tracks lessons"
    LESSONS ||--o{ LESSON_PROGRESS : "progress for"
    TRACK_COURSES }o--|| COURSES : "includes"
    TRACK_COURSES }o--|| TRACKS : "belongs to"
```

## Functions & Procedures

| Object | Purpose |
|---|---|
| `fn_user_is_active_student(id)` | True when the user is `ACTIVE` **and** holds the `STUDENT` role. |
| `sp_enroll_student(student, course, source)` | Core enrollment procedure (returns enrollment row + `already_enrolled` flag). |
| `sp_enroll_track(student, track)` | Track enrollment procedure. |
| `trg_auto_enroll_track` | After a track enroll, auto-enrolls every `PUBLISHED` course in the track with `source = 'track'`. |
| `fn_student_course_access(student, course)` | Access decision used by `GET /enrollments/courses/{id}/access`. |
| `fn_course_first_lesson_id(course)` | First lesson id by `sequence_order`. |
| `fn_prerequisite_engine_course_access(student, course)` | **External contract** (see `prerequisite.md`) — currently a placeholder returning "allowed". |

## Enrollment Flow

```mermaid
flowchart TD
    A["POST /api/v1/enrollments/courses/:courseId"] --> B[EnrollmentController]
    B --> C["CurrentUserResolver extracts student id from JWT"]
    C --> D["CALL sp_enroll_student(student, course, 'standalone')"]
    D --> E{Active student?}
    E -- "no" --> F["RAISE LTU01 -> HTTP 400"]
    E -- "yes" --> G{Course exists & published?}
    G -- "no" --> H["RAISE LTC01 -> HTTP 400"]
    G -- "yes" --> I{Already enrolled?}
    I -- "standalone, status=active" --> J["RAISE LTN01 -> HTTP 400"]
    I -- "standalone, status=completed" --> K["RAISE LTC02 -> HTTP 400"]
    I -- "track source, existing row" --> L["return already_enrolled=true"]
    I -- "not enrolled" --> M{Prerequisite engine allows?}
    M -- "no" --> N["RAISE LTP01 -> HTTP 400"]
    M -- "yes" --> O["INSERT enrollments (source=standalone)"]
    O --> P["trg_initialize_lesson_progress inserts locked lessons"]
    O --> Q["trg_unlock_first_lesson unlocks lesson 1"]
    P --> R["200 ApiResponse{data: EnrollmentResponse}"]
```

## Domain Error Codes

| Code | Meaning | HTTP |
|---|---|---|
| `LTU01` | Only active students can enroll. | 400 |
| `LTC01` | Course/track does not exist or is not published. | 400 |
| `LTT01` | Track does not exist or is not published. | 400 |
| `LTN01` | Already enrolled (active) in the course. | 400 |
| `LTN02` | Already enrolled in the track. | 400 |
| `LTC02` | Course already completed and cannot be re-enrolled. | 400 |
| `LTP01` | Prerequisites not satisfied (delegated to prerequisite engine). | 400 |
| `LT500` | Unexpected database error (logged; generic message to client). | 400 |

## Indexes

- `idx_enrollments_user_status` on `enrollments(user_id, status)`
- `idx_lesson_progress_enrollment_status` on `lesson_progress(enrollment_id, status)`
- `idx_track_enrollments_user_status` on `track_enrollments(user_id, status)`

## Trigger Summary

| Trigger | Fires | Effect |
|---|---|---|
| `trg_initialize_lesson_progress` | `AFTER INSERT` on `enrollments` | Creates a `locked` `lesson_progress` row per lesson. |
| `trg_unlock_first_lesson` | `AFTER INSERT` on `enrollments` | Unlocks the first lesson (if the prerequisite engine allows). |
| `trg_auto_enroll_track` | `AFTER INSERT` on `track_enrollments` | Auto-enrolls published track courses. |
| `trg_prevent_duplicate_enrollment` | `BEFORE INSERT` on `enrollments` | Raises `LTN01` on a duplicate active enrollment. |
| `trg_update_course_progress` | `AFTER INSERT/UPDATE/DELETE` on `lesson_progress` | Recomputes course progress; completes at 100%. |
| `trg_update_track_progress` | `AFTER INSERT/UPDATE` on `enrollments` | Recomputes track progress; completes at 100%. |
| `trg_unlock_track_courses_after_completion` | `AFTER UPDATE OF status` on `enrollments` | Unlocks first lessons of affected track courses after a course completes. |
