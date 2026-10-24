-- Migration 004: Roster versioning and verification attempts

CREATE TABLE IF NOT EXISTS roster_versions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE RESTRICT,
  uploaded_by    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  uploaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  row_count      INTEGER NOT NULL CHECK (row_count >= 0),
  file_path      TEXT NOT NULL,
  version_label  TEXT NOT NULL,
  is_active      BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (institution_id, version_label)
);

CREATE INDEX IF NOT EXISTS idx_roster_versions_institution
  ON roster_versions (institution_id) WHERE is_active = TRUE;

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS roster_rows (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id    UUID NOT NULL REFERENCES roster_versions(id) ON DELETE CASCADE,
  enrollment_no TEXT NOT NULL,
  name          TEXT NOT NULL,
  programme     TEXT,
  year          TEXT,
  is_claimed    BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (version_id, enrollment_no)
);

CREATE INDEX IF NOT EXISTS idx_roster_rows_version  ON roster_rows (version_id);
CREATE INDEX IF NOT EXISTS idx_roster_rows_enroll   ON roster_rows (enrollment_no);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS verification_attempts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliation_id  UUID NOT NULL REFERENCES affiliations(id) ON DELETE RESTRICT,
  method          TEXT NOT NULL CHECK (method IN ('roster', 'document', 'manual')),
  ocr_raw         JSONB NULL,
  user_corrected  JSONB NULL,
  ocr_confidence  REAL NULL,
  outcome         TEXT NOT NULL,
  reviewed_by     UUID NULL REFERENCES users(id) ON DELETE RESTRICT,
  reviewed_at     TIMESTAMPTZ NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
  -- Verification source documents are deleted per retention policy (30 days after decision)
  -- ocr_raw and user_corrected fields hold extracted metadata only, not the raw document
);

CREATE INDEX IF NOT EXISTS idx_verification_affiliation
  ON verification_attempts (affiliation_id);
