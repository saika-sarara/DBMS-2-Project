# Learnova Database Migrations

This directory is the only executable source of truth for the Learnova PostgreSQL database.

## Structure

```text
migration/
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