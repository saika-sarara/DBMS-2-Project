-- Enable UUID extension for unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pgcrypto for password hashing if needed at DB layer
CREATE EXTENSION IF NOT EXISTS "pgcrypto";