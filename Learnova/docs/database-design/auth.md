# Authentication Module Database Architecture

## Tables
1. **users**: Primary user accounts storing credentials and account status.
2. **roles**: Role definition lookup table (ROLE_ADMIN, ROLE_INSTRUCTOR, ROLE_STUDENT).
3. **user_roles**: Junction table mapping users to their assigned roles (Many-to-Many).

## Triggers & Procedures
- `trg_users_updated_at`: Maintains accurate timestamping upon profile updates.
- `sp_manage_user_role`: Stored procedure providing idempotent role assignment/revocation.