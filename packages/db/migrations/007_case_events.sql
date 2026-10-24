-- Migration 007: Case events — append-only, hash-chained audit log
-- CRITICAL security rules (enforced via grants after migration):
--   * App database role gets INSERT + SELECT only — no UPDATE, no DELETE
--   * Corrections are new events pointing to the prior event, never overwrites
--   * event_hash = SHA256(prev_event_hash || event_type || actor_id || event_at || payload)

CREATE TABLE IF NOT EXISTS case_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id    UUID NOT NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  event_type      TEXT NOT NULL,
  actor_id        UUID NULL REFERENCES users(id) ON DELETE RESTRICT,  -- NULL for system events
  actor_role      TEXT NOT NULL,
  bureau          TEXT NULL,
  old_state       JSONB NULL,     -- snapshot of relevant fields before change
  new_state       JSONB NULL,     -- snapshot after change
  remarks         TEXT NULL,
  document_ids    UUID[] NOT NULL DEFAULT '{}',
  event_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  prev_event_hash TEXT NULL,      -- NULL only for the first event of a complaint
  event_hash      TEXT NOT NULL,  -- SHA256 of the chain at this point
  UNIQUE (complaint_id, event_at, id)
);

CREATE INDEX IF NOT EXISTS idx_case_events_complaint  ON case_events (complaint_id, event_at);
CREATE INDEX IF NOT EXISTS idx_case_events_actor      ON case_events (actor_id);
CREATE INDEX IF NOT EXISTS idx_case_events_type       ON case_events (event_type);

-- Prevent any UPDATE or DELETE on this table at the database level.
-- This runs after the app_role is created; adjust role name to match your Supabase setup.
-- In Supabase, the authenticated role is 'authenticated'; anon role is 'anon'.
-- The service_role bypasses RLS but we restrict via policy + app design.
REVOKE UPDATE, DELETE ON case_events FROM authenticated;
REVOKE UPDATE, DELETE ON case_events FROM anon;
