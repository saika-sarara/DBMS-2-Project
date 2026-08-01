# Learnova Development Setup Guide

Welcome to **Learnova**! This guide will help every team member set up their local development environment before contributing to the project.

---

# Tech Stack

| Component | Technology |
|------------|------------|
| Language | Java 21 |
| Framework | Spring Boot 3.5.x |
| Build Tool | Maven 3.9+ |
| Database | PostgreSQL 18 |
| Cloud Database | Neon |
| Migration Tool | Flyway |
| Authentication | Spring Security + JWT |
| API Documentation | SpringDoc OpenAPI |
| IDE | Visual Studio Code |
| Version Control | Git + GitHub |

---

# Prerequisites

Install the following software before cloning the repository.

## Required Software

- Git
- Java JDK 21
- Apache Maven 3.9+
- PostgreSQL 18
- Visual Studio Code

---

# VS Code Extensions

Install these extensions from the VS Code Marketplace.

### Java Extension Pack

Publisher: Microsoft

Includes:

- Language Support for Java™ by Red Hat
- Maven for Java
- Debugger for Java
- Test Runner for Java
- Project Manager for Java

---

### Spring Boot Extension Pack

Publisher: VMware

Includes:

- Spring Boot Dashboard
- Spring Boot Tools
- Spring Initializr Support

---

### PostgreSQL

Recommended for viewing and querying databases.

---

### GitLens

Recommended for Git history and code review.

---

# Clone the Repository

```bash
git clone <repository-url>
cd Learnova
```

Open the project:

```bash
code .
```

> **Important:** Open the **Learnova** project root, **not** the `src` folder.

Correct:

```
Learnova/
│── pom.xml
│── src/
│── database/
│── frontend/
```

Incorrect:

```
Learnova/src/
```

---

# Verify Java Installation

Run:

```bash
java -version
```

Expected:

```
Java 21
```

Check the compiler:

```bash
javac -version
```

Verify Maven:

```bash
mvn -version
```

Expected output:

```
Apache Maven 3.9+
Java version: 21
```

---

# Verify Maven Build

Run:

```bash
mvn clean install
```

Expected output:

```
BUILD SUCCESS
```

If the build fails, resolve the issue before starting development.

---

# PostgreSQL Setup

Install PostgreSQL 18.

Recommended local configuration:

| Setting | Value |
|---------|-------|
| Host | localhost |
| Port | 5433 |
| Database | learnova |
| Username | postgres |
| Password | Your Password |

> The database schema and migrations are maintained separately using Flyway.

---

# Neon Database

The shared development/production database will be hosted on **Neon**.

Only the database maintainer should create or modify the database.

Other developers only need the connection credentials.

---

# Environment Variables

Create a local environment configuration.

Do **NOT** commit credentials to Git.

Example:

```env
DB_URL=jdbc:postgresql://localhost:5433/learnova
DB_USERNAME=postgres
DB_PASSWORD=your_password

JWT_SECRET=replace-with-a-secure-secret
```

Commit only:

```
.env.example
```

Never commit:

```
.env
```

---

# Application Configuration

The project reads database configuration from environment variables.

Example configuration:

```properties
spring.application.name=learnova

spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}

spring.datasource.driver-class-name=org.postgresql.Driver

spring.jpa.hibernate.ddl-auto=none

spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true

spring.flyway.enabled=true
spring.flyway.locations=classpath:db/migration
```

---

# Flyway

Database migrations are located in:

```
src/main/resources/db/migration
```

Migration naming convention:

```
V1__extensions.sql
V2__users.sql
V3__courses.sql
...
```

**Important**

- Never modify an existing migration after it has been committed.
- Create a new migration for every schema change.

---

# Running the Application

Compile:

```bash
mvn clean compile
```

Package:

```bash
mvn clean package
```

Run tests:

```bash
mvn test
```

Run the application:

```bash
mvn spring-boot:run
```

---

# Project Structure

```
src/
└── main/
    ├── java/
    │   └── com/
    │       └── learnova/
    │           ├── authentication/
    │           ├── user/
    │           ├── course/
    │           ├── enrollment/
    │           ├── prerequisite/
    │           ├── progress/
    │           ├── quiz/
    │           ├── review/
    │           ├── certificate/
    │           ├── admin/
    │           ├── security/
    │           ├── config/
    │           └── common/
    └── resources/
        ├── application.properties
        └── db/
            └── migration/
```

Each feature follows the same architecture:

```
feature/
├── controller/
├── service/
├── repository/
├── dto/
└── model/
```

---

# Git Workflow

Never work directly on **main**.

1. Update the development branch.

```bash
git checkout develop
git pull origin develop
```

2. Create a feature branch.

```bash
git checkout -b feature/course
```

3. Implement your feature.

4. Verify the project builds.

```bash
mvn clean install
```

5. Commit your changes.

```bash
git add .
git commit -m "feat(course): implement course service"
```

6. Push your branch.

```bash
git push origin feature/course
```

7. Open a Pull Request targeting `develop`.

---

# Development Guidelines

- Keep controllers thin.
- Business logic belongs in services.
- Repositories should only access the database.
- Use DTOs for API requests and responses.
- Do not expose JPA entities directly.
- Validate incoming requests.
- Follow existing package conventions.
- Write meaningful commit messages.

---

# Common VS Code Commands

Reload Java projects:

```
Ctrl + Shift + P

Java: Reload Projects
```

Clean Java Language Server:

```
Ctrl + Shift + P

Java: Clean Java Language Server Workspace
```

Reload Maven project:

```
Ctrl + Shift + P

Maven: Reload Project
```

---

# Troubleshooting

## Maven cannot find pom.xml

Run Maven from the project root.

Correct:

```
Learnova/
```

Incorrect:

```
Learnova/src/
```

---

## Java Version Mismatch

Verify:

```bash
java -version
javac -version
mvn -version
```

All three should report Java 21.

---

## Build Failure

Clean and rebuild:

```bash
mvn clean install
```

---

## Database Connection Issues

Verify:

- PostgreSQL is running.
- The correct port is being used.
- Environment variables are configured.
- Database credentials are correct.

---

# Project Status

Current project bootstrap includes:

- Java 21
- Maven
- Spring Boot
- Feature-based project architecture
- PostgreSQL driver
- Flyway integration
- Spring Security
- JWT dependencies
- OpenAPI dependencies

The remaining work includes database schema implementation, backend business logic, frontend development, and testing.

---

Happy Coding! 