-- Migration 001: Enable required PostgreSQL extensions
-- Run this first; all subsequent migrations depend on these extensions.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";     -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pg_trgm";       -- fuzzy institution name matching (Phase 3)
CREATE EXTENSION IF NOT EXISTS "vector";        -- pgvector for embeddings (Phase 3)
CREATE EXTENSION IF NOT EXISTS "pg_net";        -- async HTTP calls if needed
