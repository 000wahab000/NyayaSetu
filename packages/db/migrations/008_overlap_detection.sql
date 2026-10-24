-- Migration 008: Overlap detection tables

CREATE TABLE IF NOT EXISTS overlap_alerts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  institution_id  UUID NOT NULL REFERENCES institutions(id) ON DELETE RESTRICT,
  alert_type      TEXT NOT NULL CHECK (alert_type IN ('coordination', 'related')),
  status          TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open','linked','dismissed','reopened')),
  complaint_ids   UUID[] NOT NULL,     -- array of involved complaint IDs
  match_factors   JSONB NOT NULL DEFAULT '{}',  -- scoring breakdown for Alert 2
  triggered_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_by     UUID NULL REFERENCES users(id) ON DELETE RESTRICT,
  reviewed_at     TIMESTAMPTZ NULL,
  review_reason   TEXT NULL,
  reopened_by     UUID NULL REFERENCES users(id) ON DELETE RESTRICT,
  reopened_at     TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_overlap_alerts_institution
  ON overlap_alerts (institution_id, status, alert_type);
CREATE INDEX IF NOT EXISTS idx_overlap_alerts_open
  ON overlap_alerts (status, triggered_at) WHERE status = 'open';

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS case_links (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id        UUID NOT NULL REFERENCES overlap_alerts(id) ON DELETE RESTRICT,
  complaint_a_id  UUID NOT NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  complaint_b_id  UUID NOT NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  lead_bureau     TEXT NOT NULL,
  link_reason     TEXT NOT NULL,
  linked_by       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  linked_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT distinct_complaints CHECK (complaint_a_id <> complaint_b_id),
  -- Canonical ordering so (A,B) and (B,A) are the same pair
  CONSTRAINT canonical_pair CHECK (complaint_a_id < complaint_b_id)
);

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dismissed_pairs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_a_id  UUID NOT NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  complaint_b_id  UUID NOT NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  dismissed_by    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  dismissed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason          TEXT NOT NULL,
  can_reopen      BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT distinct_dismissed CHECK (complaint_a_id <> complaint_b_id),
  CONSTRAINT canonical_dismissed_pair CHECK (complaint_a_id < complaint_b_id),
  UNIQUE (complaint_a_id, complaint_b_id)
);
