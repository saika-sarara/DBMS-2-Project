# Learnova — A Role-Based Online Learning Platform with Prerequisite Engine

**CSE 4410: Database Management Systems II Lab**  
**Department of Software Engineering**  
**Islamic University of Technology (IUT)**

---

## Table of Contents

- [Project Overview](#project-overview)
- [Team Members](#team-members)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Database Schema Overview](#database-schema-overview)
- [Key RDBMS Implementations](#key-rdbms-implementations)
- [API Endpoints](#api-endpoints)
- [Entity Relationship Diagram](#entity-relationship-diagram)

---

## Project Overview

Learnova is a role-based online learning platform designed to enforce structured course progression through a prerequisite engine. The system supports three distinct user roles — Student, Instructor, and Admin — each with tailored access controls. It leverages PostgreSQL 18 features including recursive CTEs, window functions, triggers, stored procedures, and GIN indexes to implement academic workflows such as prerequisite-aware enrollment, auto-graded quizzes, progress tracking, and certificate issuance.

---

## Team Members

| ID | Name | GitHub |
| :--- | :--- | :--- |
| 230042127 | Maliha Tasnim Khan | [https://github.com/tasnim240](https://github.com/tasnim240) |
| 230042135 | Khadiza Sultana | [https://github.com/tayma-06](https://github.com/tayma-06) |
| 230042159 | Saika Sarara | [https://github.com/saika-sarara](https://github.com/saika-sarara) |

---

## Tech Stack

| Layer | Technology | Role |
| :--- | :--- | :--- |
| Database | PostgreSQL 18 | Primary relational database with advanced SQL features |
| Backend | Java Spring Boot | REST API server and business logic layer |
| Frontend | HTML / CSS / JavaScript | Client-side user interface |
| Templating | Jinja2 | Server-side HTML template rendering |

---

## Features

| # | Feature | Key Database Technique |
| :--- | :--- | :--- |
| 1 | Role-Based Access Control | Row-level security policies; role enum column with CHECK constraints |
| 2 | Authentication & Security | pgcrypto extension for bcrypt hashing (crypt + gen_salt); JWT token validation |
| 3 | Course Catalogue & Discovery | GIN index on tsvector column for full-text search; pg_trgm for fuzzy autocomplete |
| 4 | Prerequisite Engine | Recursive CTE (WITH RECURSIVE) for DAG traversal; cycle detection via BEFORE INSERT trigger |
| 5 | Bypass Exam System | Instructor-enabled bypass with attempt limit (2) and score threshold (80%) enforced at DB level |
| 6 | Enrollment System | Duplicate prevention via UNIQUE constraint; waiver flag; trigger-driven auto track enrollment |
| 7 | Module & Content Management | Ordered modules via positional integer column; polymorphic resource types (video, PDF, link, text) |
| 8 | Quiz & Assessment | Auto-graded MCQ with configurable time limits, passing thresholds, and attempt caps |
| 9 | Progress Tracking | AFTER INSERT / UPDATE triggers recalculating module, course, and track completion percentages |
| 10 | Track System | Career-path course bundles with track-level prerequisites; certificate eligibility at 100% completion |
| 11 | Review & Rating System | Weighted average using AVG() OVER; one review per user per course enforced by UNIQUE constraint |
| 12 | Certificate System | UUID-based primary key; instructor verification flag; public verification endpoint |
| 13 | Admin Dashboard | Aggregate queries for platform statistics; immutable audit log table with INSERT-only triggers |

---

## Database Schema Overview

The schema is organized into the following table groups:

- **Users** — `users`, `roles` (enum), `user_roles`
- **Courses** — `courses`, `categories`, `course_tags`, `course_search_index`
- **Prerequisites** — `prerequisites` (self-referencing course DAG with cycle detection)
- **Tracks** — `tracks`, `track_courses`, `track_prerequisites`
- **Enrollment** — `enrollments` (with waiver support and duplicate prevention)
- **Progress** — `module_progress`, `course_progress`, `track_progress` (trigger-driven)
- **Quizzes** — `quizzes`, `quiz_questions`, `quiz_attempts`, `quiz_answers`
- **Bypass Exams** — `bypass_exams`, `bypass_attempts`
- **Reviews** — `reviews` (weighted rating with one-per-user constraint)
- **Certificates** — `certificates` (UUID-based, instructor-verified)

---

## Key RDBMS Implementations

| Feature | PostgreSQL Technique | Purpose |
| :--- | :--- | :--- |
| Prerequisite Chain Traversal | Recursive CTE (`WITH RECURSIVE`) | Walk course prerequisite DAG to validate enrollment eligibility |
| Automated Grading & Reporting | Window Functions: `RANK()`, `DENSE_RANK()`, `NTILE()`, `LAG()`, `AVG() OVER` | Rank quiz attempts, compute percentile distributions, calculate running averages |
| Password Hashing | pgcrypto: `crypt()`, `gen_salt('bf')` | Secure bcrypt hashing before user record insertion |
| UUID Generation | pgcrypto: `gen_random_uuid()` | Primary key generation for certificates and audit records |
| Full-Text Search | GIN Index on `tsvector` column | Fast course discovery via natural language search queries |
| Fuzzy Autocomplete | GIN Index on `pg_trgm` | Typo-tolerant search suggestions in the course catalogue |
| Active Enrollments Query | Partial B-Tree Index (`WHERE status = 'active'`) | Efficient filtering of current enrollments |
| Published Courses Query | Partial B-Tree Index (`WHERE is_published = true`) | Optimize catalogue queries to only show published courses |
| Course Content Ordering | `ORDER BY position` with trigger-enforced sequence | Maintain consistent module ordering within a course |
| Cycle Detection | `BEFORE INSERT` trigger on prerequisites | Reject edges that would create a cycle in the prerequisite DAG |
| Progress Recalculation | `AFTER INSERT` / `AFTER UPDATE` triggers | Automatically update module, course, and track completion on grade changes |
| Enrollment Transactions | Stored Procedure | Atomic enrollment with prerequisite checks, duplicate prevention, and logging |
| Quiz Grading | Stored Procedure | Atomic scoring of quiz attempts with time-limit enforcement |
| Certificate Issuance | Stored Procedure | Conditional certificate generation on 100% track completion |

---

## API Endpoints

### Student Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| GET | `/api/courses` | Browse published courses with search and filter |
| GET | `/api/courses/{id}` | View course details and syllabus |
| POST | `/api/enrollments` | Enroll in a course (checks prerequisites) |
| GET | `/api/progress` | View personal progress across enrollments |
| POST | `/api/quizzes/{id}/attempt` | Submit a quiz attempt |
| GET | `/api/certificates/{uuid}` | View issued certificate |
| POST | `/api/reviews` | Submit or update a course review |

### Instructor Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| POST | `/api/courses` | Create a new course |
| PUT | `/api/courses/{id}/modules` | Manage course modules and content |
| POST | `/api/courses/{id}/quizzes` | Create or modify quizzes |
| POST | `/api/bypass-exams` | Enable a bypass exam for a course |
| GET | `/api/enrollments?course_id={id}` | View enrolled students |
| PUT | `/api/certificates/{uuid}/verify` | Approve or reject a certificate |

### Admin Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| GET | `/api/admin/users` | List and manage user accounts |
| GET | `/api/admin/stats` | View platform-wide statistics |
| PUT | `/api/admin/users/{id}/role` | Modify user roles |
| GET | `/api/admin/audit-logs` | View immutable audit log entries |

---

## Entity Relationship Diagram

The full entity relationship diagram is available at `docs/er-diagram.png`.

---

*Submitted for SWE 4402 — Islamic University of Technology*
