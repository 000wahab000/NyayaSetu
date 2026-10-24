-- Migration 002: Core identity tables — institutions and users
-- Invariants:
--   * Never hard-delete institutions or users referenced by cases/events (soft delete only)
--   * Role is stored in role_assignments, NOT as a column on users

CREATE TABLE IF NOT EXISTS institutions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aicte_permanent_id  TEXT UNIQUE NOT NULL,
  name                TEXT NOT NULL,
  region              TEXT NOT NULL,
  address             TEXT,
  type                TEXT NOT NULL,
  status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ NULL  -- soft delete only
);

-- Trigram index for Phase 3 fuzzy name matching
CREATE INDEX IF NOT EXISTS idx_institutions_name_trgm
  ON institutions USING GIN (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_institutions_aicte_id
  ON institutions (aicte_permanent_id);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT UNIQUE,
  phone         TEXT UNIQUE,
  display_name  TEXT NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT users_email_or_phone CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_users_email   ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_active  ON users (is_active) WHERE is_active = TRUE;
