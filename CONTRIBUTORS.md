# Project Contributors

Thank you to every member of the **Learnova** team for their dedication, hard work, and collaborative spirit. This project is the result of careful planning and shared effort across authentication, application architecture, and database engineering. Each contributor's unique skills made Learnova possible.

The codebase is divided into clear ownership areas. Keep changes inside your area and
consult `docs/database-design/*.md` before touching schema-adjacent code.

### Maliha Tasnim Khan — Authentication, Security & Database Schema

- **Database schema creation**: Flyway migrations `V1` (extensions/common functions),
  `V2` (users, roles, user_roles), `V4` (instructor_requests), `V5` (account status).
- **Authentication**: `AuthController`, `AuthService`, register/login DTOs, bcrypt hashing.
- **Security configuration**: `SecurityConfig` (filter chain, public vs. protected routes),
  `CustomUserDetailsService`, `UserPrincipal`, `AuthenticationEntryPoint`,
  `AccessDeniedHandler`, `GlobalExceptionHandler`.
- Owns the user/role model (`User`, `Role`, `UserProfileResponse`) and the `ApiResponse` envelope.

### Khadiza Sultana — JWT, Enrollment & Frontend

- **JWT**: `JwtService` (HS256 sign/validate), `JwtAuthenticationFilter`, token claims/expiry.
- **Enrollment**: `EnrollmentController`, `EnrollmentService`, `EnrollmentRepository` /
  `EnrollmentCommandRepository`, `CurrentUserResolver`, enrollment DTOs — invoking the
  DB procedures `sp_enroll_student()` / `sp_enroll_track()` and forwarding `LTxxx` codes.
- **Frontend**: `frontend/js/` — `apiClient` (Bearer header), `authApi`, `enrollmentApi`,
  session store, `routeGuard`, `login.js`, `register.js`, `navbar.js`, and the student pages.

### Saika Sarara — Course Catalogue & Neon / Database Connection

- **Course catalogue**: the course contract (courses, lessons, tracks, track_courses),
  the seed catalog mirroring the frontend mock data, and the planned course/public
  catalogue API (`GET /api/v1/courses/**`).
- **Neon setup & database connection**: Neon project configuration, `.env` /
  `.env.example`, `application.properties` datasource (Flyway, JPA `validate`),
  `scripts/run-dev.ps1`, and the Flyway integration that connects the app to Neon.

> Shared conventions: migrations must stay additive (new `Vx__...` files), domain
> rules stay in the DB, and all API responses use the `ApiResponse` envelope.

## Contributing

We welcome contributions from the community! To get started:

1. **Fork** the repository on GitHub.
2. **Create a feature branch** from `develop`:

   ```bash
   git checkout -b feature/your-feature
   ```

3. **Commit your changes** with clear, descriptive messages.

   ```bash
   git add .
   git commit -m "feat(module): describe your change"
   ```

4. **Push** your branch to your fork:

   ```bash
   git push origin feature/your-feature
   ```

5. **Open a Pull Request** targeting the `develop` branch and describe the changes you made.

Please follow the existing code conventions, keep controllers thin and services focused on business logic, and verify the project builds with `mvn clean install` before submitting your pull request. Every contribution, big or small, is greatly appreciated.