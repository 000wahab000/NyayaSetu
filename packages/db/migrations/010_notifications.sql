-- Migration 010: Notifications system
-- Rule: notification content NEVER contains complaint text, allegations, or attachments.
-- Notifications say *what happened* and link to the authenticated portal only.

CREATE TABLE IF NOT EXISTS notification_policies (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type            TEXT NOT NULL,
  recipient_role        TEXT NOT NULL,
  channel               TEXT NOT NULL CHECK (channel IN ('in_app', 'email', 'web_push')),
  template_key          TEXT NOT NULL,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  -- 'restricted' means: for sensitive cases, recipients resolved from AICTE-only path
  restricted_case_rule  TEXT NOT NULL DEFAULT 'standard',
  UNIQUE (event_type, recipient_role, channel)
);

-- Seed essential notification policies
INSERT INTO notification_policies (event_type, recipient_role, channel, template_key, restricted_case_rule) VALUES
  ('complaint_submitted',       'pgrc_triage_officer', 'in_app',  'complaint_submitted_officer',    'standard'),
  ('complaint_submitted',       'student',             'in_app',  'complaint_submitted_student',    'standard'),
  ('complaint_referred',        'college_management',  'in_app',  'complaint_referred_college',     'standard'),
  ('complaint_referred',        'student',             'in_app',  'complaint_referred_student',     'standard'),
  ('deadline_nearing',          'pgrc_triage_officer', 'in_app',  'deadline_nearing_officer',       'standard'),
  ('deadline_nearing',          'student',             'in_app',  'deadline_nearing_student',       'standard'),
  ('deadline_overdue',          'bureau_head',         'in_app',  'deadline_overdue_bureau_head',   'standard'),
  ('overlap_alert_coordination','pgrc_triage_officer', 'in_app',  'overlap_coordination',           'standard'),
  ('overlap_alert_coordination','bureau_officer',      'in_app',  'overlap_coordination',           'standard'),
  ('case_closed',               'student',             'in_app',  'case_closed_student',            'standard'),
  ('case_closed',               'student',             'email',   'case_closed_student_email',      'standard'),
  -- Sensitive rule: complaints involving management never notify college_management
  ('complaint_submitted',       'college_management',  'in_app',  'complaint_submitted_college',    'restricted_skip_management')
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS notifications (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  complaint_id     UUID NULL REFERENCES complaints(id) ON DELETE RESTRICT,
  event_type       TEXT NOT NULL,
  channel          TEXT NOT NULL CHECK (channel IN ('in_app', 'email', 'web_push')),
  status           TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','sent','failed','read')),
  idempotency_key  TEXT UNIQUE NOT NULL,  -- prevents duplicate sends on retry
  sent_at          TIMESTAMPTZ NULL,
  read_at          TIMESTAMPTZ NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, created_at) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_pending
  ON notifications (status, created_at) WHERE status = 'pending';
