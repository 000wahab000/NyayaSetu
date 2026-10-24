-- Migration 011: Audit events — append-only security log
-- Every login, role change, sensitive case view, and config change writes here.
-- App role has INSERT + SELECT only — no UPDATE, no DELETE.

CREATE TABLE IF NOT EXISTS audit_events (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id       UUID NULL REFERENCES users(id) ON DELETE RESTRICT,  -- NULL for system
  action         TEXT NOT NULL,         -- e.g. 'user.login', 'role.grant', 'case.view_sensitive'
  resource_type  TEXT NOT NULL,         -- e.g. 'complaint', 'role_assignment', 'user'
  resource_id    UUID NULL,
  old_value      JSONB NULL,
  new_value      JSONB NULL,
  ip_address     INET NULL,
  session_id     UUID NULL,
  reason         TEXT NULL,             -- required for admin overrides and config changes
  event_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_events_actor     ON audit_events (actor_id, event_at);
CREATE INDEX IF NOT EXISTS idx_audit_events_resource  ON audit_events (resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_audit_events_action    ON audit_events (action, event_at);

-- Prevent UPDATE and DELETE on audit log
REVOKE UPDATE, DELETE ON audit_events FROM authenticated;
REVOKE UPDATE, DELETE ON audit_events FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 012: Reserved tables for Phase 5-6 (schema reservation — no data yet)

CREATE TABLE IF NOT EXISTS policy_chunks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_name TEXT NOT NULL,
  section       TEXT NOT NULL,
  page          TEXT NULL,
  content_text  TEXT NOT NULL,
  embedding     VECTOR(768) NOT NULL,
  indexed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Reserved for Phase 6 RAG; no data written in Phase 1.

CREATE TABLE IF NOT EXISTS report_runs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_type   TEXT NOT NULL,
  requested_by  UUID REFERENCES users(id) ON DELETE RESTRICT,
  params        JSONB NOT NULL DEFAULT '{}',
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','running','done','failed')),
  file_path     TEXT NULL,
  generated_at  TIMESTAMPTZ NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Reserved for Phase 6 report generation.
