# Learnova Database Migrations

This directory is the single source of truth for the Learnova PostgreSQL schema and database business logic.

## Structure

```text
db/migration/
├── README.md
│
├── versioned/
│   ├── core/
│   ├── course/
│   ├── enrollment/
│   ├── prerequisite/
│   ├── quiz/
│   ├── platform/
│   └── seed/
│
└── repeatable/
    ├── functions/
    ├── procedures/
    ├── triggers/
    └── views/