# Authentication Module — Database Architecture

Status: **Implemented** (migrations `V1`–`V2`; design file `database/auth.sql`).
Enforced by: `AuthService`, `JwtService`, `JwtAuthenticationFilter`, `SecurityConfig`.

## Tables

| Table | Purpose |
|---|---|
| `users` | Primary user accounts storing credentials and account status. |
| `roles` | Role lookup table: `STUDENT`, `INSTRUCTOR`, `ADMIN`. |
| `user_roles` | Junction table mapping users to their assigned roles (many-to-many). |
| `instructor_requests` | Student requests to become an instructor (`PENDING`/`APPROVED`/`REJECTED`). |

### `users`
- `email` is `citext` (case-insensitive), `UNIQUE`.
- `password_hash` stores a **bcrypt** hash (`$2b$...`).
- `account_status` — exactly one of `ACTIVE`, `SUSPENDED`, `BANNED` (enforced by
  `chk_users_account_status`).
- `created_at` / `updated_at` maintained automatically; `updated_at` is kept fresh by
  `trg_users_set_updated_at` (uses the `set_updated_at()` helper from `V1`).

### `roles`
- `name` is `UNIQUE` and `CHECK`-constrained to `STUDENT`, `INSTRUCTOR`, `ADMIN`.
- Seeded by `V2`.

### `user_roles`
- Composite primary key `(user_id, role_id)`.
- FKs: `user_id → users` (`CASCADE`), `role_id → roles` (`RESTRICT`), `granted_by → users` (`SET NULL`).

### `instructor_requests`
- FKs: `user_id → users` (`CASCADE`), `reviewed_by → users` (`SET NULL`).
- Status `CHECK` — `PENDING`, `APPROVED`, `REJECTED` (frontend stores these lowercase).
- Indexed on `(user_id, status)` and `(status, created_at)`.

## ER Diagram

```mermaid
erDiagram
    USERS {
        bigint id PK
        citext email UK
        varchar password_hash
        varchar first_name
        varchar last_name
        varchar account_status
        timestamptz created_at
        timestamptz updated_at
    }
    ROLES {
        smallint id PK
        varchar name UK
        varchar description
        timestamptz created_at
    }
    USER_ROLES {
        bigint user_id PK,FK
        smallint role_id PK,FK
        bigint granted_by FK
        timestamptz granted_at
    }
    INSTRUCTOR_REQUESTS {
        bigint id PK
        bigint user_id FK
        varchar status
        text request_message
        bigint reviewed_by FK
        timestamptz reviewed_at
        text rejection_reason
        timestamptz created_at
    }

    USERS ||--o{ USER_ROLES : "has roles"
    ROLES ||--o{ USER_ROLES : "assigned to"
    USERS ||--o{ INSTRUCTOR_REQUESTS : "submits"
    USERS ||--o{ INSTRUCTOR_REQUESTS : "reviews"
```

## Triggers & Procedures

- `trg_users_set_updated_at` — `BEFORE UPDATE` on `users`, calls `set_updated_at()`.
- `sp_manage_user_role` — idempotent role assignment/revocation (module boundary used by services).

## Auth / JWT Flow

```mermaid
sequenceDiagram
    participant FE as Frontend
    participant API as AuthController
    participant SVC as AuthService
    participant DB as PostgreSQL (Neon)

    FE->>API: POST /api/v1/auth/register
    API->>SVC: registerUser(RegisterRequest)
    SVC->>DB: INSERT users (bcrypt hash)
    SVC->>DB: sp_manage_user_role (STUDENT)
    SVC-->>API: success message
    API-->>FE: 200 ApiResponse{message}

    FE->>API: POST /api/v1/auth/login
    API->>SVC: loginUser(LoginRequest)
    SVC->>DB: verify credentials + account_status
    SVC-->>API: LoginResponse{id, token, roles, primaryRole, status, ...}
    API-->>FE: 200 ApiResponse{data: LoginResponse}

    FE->>API: GET /api/v1/auth/me (Authorization: Bearer token)
    API->>SVC: me(principalId)
    SVC-->>API: UserProfileResponse{id, email, fullName, roles, role, status}
    API-->>FE: 200 ApiResponse{data}
```

## Account Status Rules

- `ACTIVE` — can log in and use the platform.
- `SUSPENDED` — cannot log in (login returns `403 "This account is suspended..."`).
- `BANNED` — cannot log in (login returns `403 "This account is banned..."`).

## Seed Accounts (from migrations)

The bootstrap admin (`admin@learnova.com`) is provisioned from environment
variables (`BOOTSTRAP_ADMIN_PASSWORD`). The accounts below are seeded by the
V8 migration with password `password123`:

| Email | Roles | Status |
|---|---|---|
| `sultanakhadiza37@gmail.com` | Admin | active |
| `malihatasnim@gmail.com` | Student | active |
| `saikasarara@gmail.com` | Student | active |

> Role names in the DB are uppercase (`STUDENT`/`INSTRUCTOR`/`ADMIN`); the API maps
> them to the display roles `Student`/`Instructor`/`Admin` and to Spring authorities
> `ROLE_STUDENT`/`ROLE_INSTRUCTOR`/`ROLE_ADMIN`.
