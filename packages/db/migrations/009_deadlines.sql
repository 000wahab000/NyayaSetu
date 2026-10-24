-- Migration 009: Deadline rules and deadline tracking

CREATE TABLE IF NOT EXISTS deadline_rules (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  route            TEXT NOT NULL,
  category         TEXT NULL,
  days_to_deadline INTEGER NOT NULL CHECK (days_to_deadline > 0),
  -- IMPORTANT: source_citation is mandatory; these are configurable defaults,
  -- NOT official AICTE rules. Must be labelled as such in the UI.
  source_citation  TEXT NOT NULL,
  effective_from   DATE NOT NULL DEFAULT CURRENT_DATE,
  approved_by      UUID NULL REFERENCES users(id) ON DELETE RESTRICT,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed the default configurable rules (labelled as configurable defaults, not AICTE rules)
INSERT INTO deadline_rules (name, route, category, days_to_deadline, source_citation, is_active) VALUES
  ('College referral response', 'college_referral', NULL, 15, 'UGC 2023 student grievance regulations (pattern) — configurable default, not an official AICTE rule', TRUE),
  ('Standard resolution', 'standard', NULL, 21, 'CPGRAMS 21-day target (pattern) — configurable default, not an official AICTE rule', TRUE),
  ('Appeal decision', 'appeal', NULL, 30, 'CPGRAMS appellate pattern — configurable default, not an official AICTE rule', TRUE)
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS deadlines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id    UUID NOT NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  rule_id         UUID NOT NULL REFERENCES deadline_rules(id) ON DELETE RESTRICT,
  due_at          TIMESTAMPTZ NOT NULL,
  status          TEXT NOT NULL DEFAULT 'on_track'
                    CHECK (status IN ('on_track','nearing','overdue','paused')),
  paused_reason   TEXT NULL,
  last_checked_at TIMESTAMPTZ NULL,
  UNIQUE (complaint_id, rule_id)
);

CREATE INDEX IF NOT EXISTS idx_deadlines_status_due
  ON deadlines (status, due_at) WHERE status IN ('on_track','nearing');
CREATE INDEX IF NOT EXISTS idx_deadlines_overdue
  ON deadlines (due_at) WHERE status = 'overdue';
