-- Migration 005: Complaints — the central case table
-- Six independent status tracks, each as a separate column.
-- institution_id is populated from the verified session, never from the request body.

CREATE TABLE IF NOT EXISTS complaints (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id               TEXT UNIQUE NOT NULL,  -- human-readable e.g. "NS-2026-00001"
  institution_id        UUID NOT NULL REFERENCES institutions(id) ON DELETE RESTRICT,
  submitted_by          UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  submitted_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  receipt_date          DATE NOT NULL DEFAULT CURRENT_DATE,

  -- Category (frozen MVP enum)
  category              TEXT NOT NULL CHECK (category IN ('financial','ragging','academic','infrastructure','other')),
  secondary_category    TEXT NULL CHECK (char_length(secondary_category) <= 80),

  -- Complaint content
  description_text      TEXT NOT NULL CHECK (char_length(description_text) >= 10),
  description_language  TEXT NOT NULL DEFAULT 'en',
  description_embedding VECTOR(768) NULL,  -- populated async by Phase 3 job

  -- Track 1: Lifecycle
  status TEXT NOT NULL DEFAULT 'submitted'
    CHECK (status IN (
      'submitted','under_triage','referred','awaiting_response',
      'under_examination','decision_recorded','closed','out_of_scope',
      'transferred','appeal_submitted','under_appeal_review','appeal_decided'
    )),

  -- Track 2: Verification
  verification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending','verified','needs_review','unable_to_verify')),

  -- Track 3: Coordination / Overlap
  coordination_status TEXT NOT NULL DEFAULT 'no_overlap'
    CHECK (coordination_status IN ('no_overlap','possible_overlap','linked','dismissed')),

  -- Track 4: Deadline
  deadline_status TEXT NOT NULL DEFAULT 'on_track'
    CHECK (deadline_status IN ('on_track','nearing','overdue','paused')),

  -- Track 5: Appeal
  appeal_status TEXT NOT NULL DEFAULT 'not_applicable'
    CHECK (appeal_status IN ('not_applicable','eligible','submitted','under_review','decided')),

  -- Track 6: Urgency / Triage
  urgency_status TEXT NOT NULL DEFAULT 'untriaged'
    CHECK (urgency_status IN ('untriaged','triaged','urgent','out_of_scope')),

  -- Assignment (comes from session/DB, never from request body)
  assigned_bureau       TEXT NULL,
  assigned_officer      UUID NULL REFERENCES users(id) ON DELETE RESTRICT,

  -- Action tracking
  last_action_at        TIMESTAMPTZ NULL,
  next_action           TEXT NULL,
  next_action_at        TIMESTAMPTZ NULL,
  expected_disposal_at  TIMESTAMPTZ NULL,

  -- Access control flags
  is_confidential       BOOLEAN NOT NULL DEFAULT FALSE,
  involves_management   BOOLEAN NOT NULL DEFAULT FALSE,
  is_demo               BOOLEAN NOT NULL DEFAULT FALSE,

  -- Optimistic locking (prevents concurrent state-machine races)
  version               INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),

  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for dashboard queries, filters, and deadline jobs
CREATE INDEX IF NOT EXISTS idx_complaints_institution_status
  ON complaints (institution_id, status);
CREATE INDEX IF NOT EXISTS idx_complaints_bureau_status
  ON complaints (assigned_bureau, status);
CREATE INDEX IF NOT EXISTS idx_complaints_receipt_date
  ON complaints (receipt_date);
CREATE INDEX IF NOT EXISTS idx_complaints_disposal_date
  ON complaints (expected_disposal_at);
CREATE INDEX IF NOT EXISTS idx_complaints_deadline_status
  ON complaints (deadline_status, expected_disposal_at)
  WHERE deadline_status IN ('nearing','overdue');

-- Sequence for human-readable case IDs
CREATE SEQUENCE IF NOT EXISTS complaint_case_seq START 1;

-- Function to generate case_id: NS-<YEAR>-<5-digit-seq>
CREATE OR REPLACE FUNCTION next_case_id() RETURNS TEXT AS $$
  SELECT 'NS-' || EXTRACT(YEAR FROM NOW())::TEXT || '-' || LPAD(nextval('complaint_case_seq')::TEXT, 5, '0');
$$ LANGUAGE SQL;
