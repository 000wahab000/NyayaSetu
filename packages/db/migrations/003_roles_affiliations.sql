-- Migration 003: Role assignments and affiliations
-- Invariants:
--   * institution_id / bureau / region are authoritative ONLY from this table,
--     never from request bodies. Middleware reads these and injects as headers.
--   * One active affiliation claim per user+institution+type combination.

CREATE TABLE IF NOT EXISTS role_assignments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  role            TEXT NOT NULL,
  bureau          TEXT NULL,
  institution_id  UUID NULL REFERENCES institutions(id) ON DELETE RESTRICT,
  region          TEXT NULL,
  granted_by      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at      TIMESTAMPTZ NULL,
  reason          TEXT NOT NULL DEFAULT '',
  CONSTRAINT role_scope_check CHECK (
    -- Institution-scoped roles must have institution_id
    (role IN ('college_management', 'faculty') AND institution_id IS NOT NULL)
    OR
    -- Bureau-scoped roles must have bureau
    (role IN ('pgrc_triage_officer', 'bureau_officer', 'bureau_head') AND bureau IS NOT NULL)
    OR
    -- Regional roles must have region
    (role = 'regional_officer' AND region IS NOT NULL)
    OR
    -- Global roles need no scope
    (role IN ('student', 'competent_authority', 'ombudsperson', 'auditor', 'system_admin'))
  )
);

CREATE INDEX IF NOT EXISTS idx_role_assignments_user_active
  ON role_assignments (user_id, role) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_role_assignments_institution
  ON role_assignments (institution_id) WHERE revoked_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS affiliations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  institution_id  UUID NOT NULL REFERENCES institutions(id) ON DELETE RESTRICT,
  type            TEXT NOT NULL CHECK (type IN ('current_student', 'alumnus', 'faculty')),
  enrollment_no   TEXT NULL,
  programme       TEXT NULL,
  year            TEXT NULL,
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'verified', 'needs_review', 'unable_to_verify')),
  claimed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at     TIMESTAMPTZ NULL,
  -- One active claim per user + institution + affiliation type
  UNIQUE (user_id, institution_id, type)
);

CREATE INDEX IF NOT EXISTS idx_affiliations_user       ON affiliations (user_id);
CREATE INDEX IF NOT EXISTS idx_affiliations_institution ON affiliations (institution_id, status);
