<div align="center">

# Learnova
**Learnova** is a role-based, **database-first** online learning platform designed for structured learning, prerequisite-aware course progression, interactive quizzes, learning tracks, progress tracking, and certificates.

*CSE 4410: Database Management Systems II Lab* · Department of Software Engineering · Islamic University of Technology (IUT)

<span style="display:inline-block;background:#1800ad;color:#fff;border-radius:4px;padding:4px 12px;font-weight:600;font-size:.9em;">Learnova</span>
<span style="display:inline-block;background:#1800ad;color:#fff;border-radius:4px;padding:4px 12px;font-weight:600;font-size:.9em;">Database-First PostgreSQL</span>
<span style="display:inline-block;background:#1800ad;color:#fff;border-radius:4px;padding:4px 12px;font-weight:600;font-size:.9em;">Spring Boot + JWT</span>
<span style="display:inline-block;background:#1800ad;color:#fff;border-radius:4px;padding:4px 12px;font-weight:600;font-size:.9em;">HTML · CSS · JS</span>

</div>

---

## Table of Contents

1. [Overview](#overview)
2. [Team Members](#team-members)
3. [Tech Stack](#tech-stack)
4. [Architecture](#architecture)
5. [Core Features](#core-features)
6. [Database Modules](#database-modules)
7. [Key RDBMS Work](#key-rdbms-work)
8. [API Overview](#api-overview)
9. [Environment Variables](#environment-variables)
10. [Run Locally](#run-locally)
11. [ER Diagram](#er-diagram)
12. [Documentation](#documentation)

---

## Overview

Learnova helps students learn through structured courses, guided tracks, quizzes, and certificates. Important academic rules are handled **by PostgreSQL** using constraints, functions, procedures, triggers, and indexes — keeping the frontend and backend thin.

The system supports three roles:

| Role | What they can do |
| :--- | :--- |
| <span style="display:inline-block;border:1px solid #1800ad;color:#1800ad;border-radius:4px;padding:0 8px;font-weight:600;">Student</span> | Browse courses, enroll, complete lessons, take quizzes, earn certificates |
| <span style="display:inline-block;border:1px solid #2400c4;color:#2400c4;border-radius:4px;padding:0 8px;font-weight:600;">Instructor</span> | Create and manage courses, lessons, quizzes, and learning content |
| <span style="display:inline-block;border:1px solid #5f5f7a;color:#5f5f7a;border-radius:4px;padding:0 8px;font-weight:600;">Admin</span> | Manage users, approve requests, monitor statistics, and review audit logs |

---

## Team Members

| ID | Name | GitHub |
| :--- | :--- | :--- |
| 230042127 | Maliha Tasnim Khan | [tasnim240](https://github.com/tasnim240) |
| 230042135 | Khadiza Sultana | [tayma-06](https://github.com/tayma-06) |
| 230042159 | Saika Sarara | [saika-sarara](https://github.com/saika-sarara) |

---

## Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Frontend** | HTML, CSS, JavaScript |
| **Backend** | Java Spring Boot |
| **Security** | Spring Security, JWT |
| **Database** | PostgreSQL (Neon) |
| **Migration** | Flyway |
| **API Docs** | Swagger / OpenAPI |

---

## Architecture

Learnova follows a **database-first, layered architecture**. Business rules live in the database layer, so the backend stays thin.

```text
Frontend
   ↓
Spring Boot REST API
   ↓
Database Command Layer
   ↓
PostgreSQL Functions, Procedures, Triggers, Constraints
```

| Layer | Responsibility |
| :--- | :--- |
| Frontend | Displays UI and calls APIs |
| Backend | Handles authentication, authorization, and API routing |
| Database | Enforces business rules and keeps data consistent |

---

## Core Features

| Feature | Description |
| :--- | :--- |
| Role-Based Access | Student, Instructor, and Admin access control |
| JWT Authentication | Secure login and protected API access |
| Course Catalogue | Browse and discover published courses |
| Track System | Learn through structured multi-course paths |
| Prerequisite Engine | Unlock courses based on completed requirements |
| Enrollment System | Database-driven course and track enrollment |
| Quiz System | MCQ quizzes with attempts and scoring |
| Progress Tracking | Lesson, course, and track progress updates |
| Reviews & Ratings | Course feedback from students |
| Certificates | Certificate issuing and verification |
| Admin Dashboard | User management, statistics, and audit logs |

---

## Database Modules

> **Database authority:** the schema is owned exclusively by the Flyway
> migrations in `Learnova/src/main/resources/db/migration/` (enabled via
> `spring.flyway.enabled=true`). The `Learnova/database/` folder is a **read-only
> reference view** of the same schema for review — it is never executed and must
> not be edited by hand.

| Module | Main Tables |
| :--- | :--- |
| Authentication | `users`, `roles`, `user_roles`, `instructor_requests` |
| Courses | `categories`, `courses`, `modules`, `lessons`, `lesson_content_blocks` |
| Tracks | `tracks`, `track_courses` |
| Prerequisites | `course_prerequisites`, `course_bypasses` |
| Enrollment | `enrollments`, `track_enrollments` |
| Progress | `lesson_progress` |
| Quiz | `quizzes`, `quiz_questions`, `quiz_options`, `quiz_attempts`, `attempt_answers` |
| Platform | `reviews`, `certificates`, `notifications`, `audit_logs` |

---

## Key RDBMS Work

| Area | Database Technique |
| :--- | :--- |
| Prerequisite Engine | Recursive CTE, cycle detection trigger |
| Enrollment | Stored procedure/function, unique constraints |
| Progress Tracking | AFTER INSERT / UPDATE triggers |
| Course Discovery | GIN index, full-text search |
| Quiz Grading | Database-side scoring logic |
| Certificates | UUID-based certificate verification |
| Audit Logs | Immutable audit records |

---

## API Overview

**Base URL:** `/api/v1`

### Authentication

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| <span style="display:inline-block;background:#1800ad;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">POST</span> | `/auth/register` | Register a new student |
| <span style="display:inline-block;background:#1800ad;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">POST</span> | `/auth/login` | Login and receive JWT |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/auth/me` | Get current authenticated user |

### Enrollment

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| <span style="display:inline-block;background:#1800ad;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">POST</span> | `/enrollments/courses/{courseId}` | Enroll in a course |
| <span style="display:inline-block;background:#1800ad;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">POST</span> | `/enrollments/tracks/{trackId}` | Enroll in a track |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/enrollments/my-courses` | View my course enrollments |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/enrollments/my-tracks` | View my track enrollments |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/enrollments/courses/{courseId}/access` | Check course access |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/enrollments/stats` | View enrollment statistics (admin) |

### Courses

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/courses` | Browse published courses |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/courses/{id}` | View course details |

### Admin

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/admin/users` | Manage users |
| <span style="display:inline-block;background:#2400c4;color:#fff;border-radius:4px;padding:0 8px;font-weight:600;">GET</span> | `/admin/audit-logs` | View audit logs |

> Full request/response contracts, payloads, and error codes are documented in [`docs/api-endpoints.md`](Learnova/docs/api-endpoints.md) and the live Swagger UI.

---

## Environment Variables

Create a local `.env` file (copy from `.env.example`) or configure these in your IDE:

```env
DB_URL=
DB_USERNAME=
DB_PASSWORD=

JWT_SECRET=
JWT_EXPIRATION_MS=86400000

BOOTSTRAP_ADMIN_ENABLED=false
BOOTSTRAP_ADMIN_EMAIL=
BOOTSTRAP_ADMIN_PASSWORD=
BOOTSTRAP_ADMIN_FIRST_NAME=
BOOTSTRAP_ADMIN_LAST_NAME=
```

> **Never commit** real database credentials, JWT secrets, or admin credentials.

---

## Run Locally

### 1. Start the backend

```bash
cd Learnova
mvn spring-boot:run
```

Backend URL: `http://localhost:8000`

> On Windows you can use the dev script, which loads `.env` automatically:

```powershell
./Learnova/scripts/run-dev.ps1
```

### 2. Open Swagger

```
http://localhost:8000/swagger-ui/index.html
```

Use the Swagger **Authorize** button with:

```
Bearer <your-jwt-token>
```

### 3. Start the frontend

Use VS Code Live Server or any local static server.

Example: `http://localhost:5500`

---

## ER Diagram

The full entity-relationship diagram is shown below (also available at `docs/er-diagram.png`):

<p align="center">
  <img src="./Learnova/docs/er-diagram.png" alt="Learnova ER Diagram" width="850"/>
</p>

---

## Documentation

| Document | Description |
| :--- | :--- |
| [`docs/setup-guide.md`](Learnova/docs/setup-guide.md) | Onboarding and development setup guide |
| [`docs/ARCHITECTURE.md`](Learnova/docs/ARCHITECTURE.md) | System architecture, flow, and contributor ownership |
| [`docs/api-endpoints.md`](Learnova/docs/api-endpoints.md) | Implemented API endpoints and error codes |
| [`docs/database-design/`](Learnova/docs/database-design/) | Per-module database design with Mermaid diagrams |

---

<div align="center">

**Learnova** — A clean, database-first learning platform for structured online education.

*CSE 4410 — Database Management Systems II Lab* · Islamic University of Technology

</div>
