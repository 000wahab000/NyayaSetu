-- Migration 006: Participants and Evidence

CREATE TABLE IF NOT EXISTS participants (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id    UUID NOT NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  role            TEXT NOT NULL CHECK (role IN ('complainant','officer','faculty','college_officer','auditor')),
  access_scope    TEXT NOT NULL DEFAULT 'redacted_summary'
                    CHECK (access_scope IN ('full','response_only','redacted_summary')),
  added_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  removed_at      TIMESTAMPTZ NULL,
  -- Only one active participant record per user+complaint
  UNIQUE (complaint_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_participants_complaint  ON participants (complaint_id);
CREATE INDEX IF NOT EXISTS idx_participants_user       ON participants (user_id) WHERE removed_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS evidence (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id        UUID NOT NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  uploaded_by         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  file_path           TEXT NOT NULL,        -- object storage key, NOT a public URL
  mime_type           TEXT NOT NULL,
  size_bytes          BIGINT NOT NULL CHECK (size_bytes BETWEEN 1 AND 10485760), -- max 10 MiB
  hash_sha256         TEXT NOT NULL,        -- for duplicate detection
  malware_scanned_at  TIMESTAMPTZ NULL,
  malware_clean       BOOLEAN NULL,
  uploaded_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_ocr_source       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_evidence_complaint ON evidence (complaint_id);
CREATE INDEX IF NOT EXISTS idx_evidence_hash      ON evidence (hash_sha256);

-- Enforce max 5 evidence files per complaint via trigger
CREATE OR REPLACE FUNCTION check_evidence_limit() RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM evidence WHERE complaint_id = NEW.complaint_id) >= 5 THEN
    RAISE EXCEPTION 'Maximum 5 evidence files allowed per complaint.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_evidence_limit ON evidence;
CREATE TRIGGER trg_evidence_limit
  BEFORE INSERT ON evidence
  FOR EACH ROW EXECUTE FUNCTION check_evidence_limit();
