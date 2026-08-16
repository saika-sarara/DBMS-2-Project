# Learnova Database Migrations

This directory is the single source of truth for the Learnova PostgreSQL schema and database business logic.

## Structure

```text
db/migration/
├── README.md
├── versioned/
│   ├── core/
│   ├── course/
│   ├── enrollment/
│   ├── prerequisite/
│   ├── quiz/
│   ├── platform/
│   └── seed/
└── repeatable/
    ├── functions/
    ├── procedures/
    ├── triggers/
    └── views/
```

## Versioned migrations

Versioned migrations represent immutable database history.

Examples:

```
V1__...
V2__...
...
V27__...
```

Once a versioned migration has successfully been applied to the shared database, it must not be edited.

Future structural or one-time data changes must use a new migration:

```
V28__...
V29__...
V30__...
```

Never repair application behavior by editing an already-applied versioned migration.

## Repeatable migrations

Repeatable migrations contain the current definitions of replaceable database objects such as:

- functions
- procedures
- triggers
- views

Examples:

```
R__210_prerequisite_access_functions.sql
R__310_track_auto_enrollment.sql
```

Flyway re-runs a repeatable migration when its checksum changes.

## Business-rule ownership

Learnova intentionally keeps core learning-state rules in PostgreSQL.

PostgreSQL owns:

- referential integrity
- uniqueness
- prerequisite evaluation
- prerequisite cycle prevention
- enrollment transitions
- Track enrollment behavior
- quiz attempt rules
- quiz grading
- lesson progress
- course progress
- Track progress
- certificate issuance
- review aggregates
- audit records

Spring Boot owns:

- HTTP endpoints
- authentication
- authorization
- DTO validation
- transaction boundaries
- database command invocation
- mapping database errors to API responses

The frontend owns:

- presentation
- navigation
- interaction state
- loading states
- error presentation

Business rules must not be implemented independently in JavaScript.

## Flyway safety

SQL migrations are checksum-sensitive.

The repository `.gitattributes` disables Git text normalization for:

```
*.sql
```

Do not run repository-wide SQL normalization.

Do not run:

```
git add --renormalize .
```

after migrations have been applied.

Do not automatically format historical SQL migration files.

## Frozen migration history

After Phase 0 stabilization:

```
V1-V27
```

are immutable.

Do not edit, format, rename, move or normalize these files.

Future changes must use:

```
V28+
```

or an appropriate:

```
R__...
```

repeatable migration.

## Current-definition strategy

Historical migrations explain how the database reached its current state.

Current replaceable database behavior should progressively be represented under:

```
repeatable/
```

This allows developers and reviewers to identify the current definitions of functions, procedures, triggers and views without searching through all historical migrations.

## Architecture principle

The intended final architecture is:

```
PostgreSQL
    owns integrity and learning-state business rules
Spring Boot
    owns HTTP, authentication, authorization and API mapping
Frontend
    owns presentation and interaction
```

The same business rule should not be independently implemented in multiple layers.