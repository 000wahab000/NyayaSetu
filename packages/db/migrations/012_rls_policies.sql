-- Migration 012: Row-Level Security Policies
-- Two-lock model: application middleware (middleware.ts) + PostgreSQL RLS.
-- If the app has a bug, RLS at the DB level rejects the query.
-- institution_id / bureau / region ALWAYS come from role_assignments, never request body.

-- ═══════════════════════════════════════════════════════════════════════════
-- Enable RLS on all sensitive tables
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE institutions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_assignments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliations           ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints             ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants           ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence               ENABLE ROW LEVEL SECURITY;
ALTER TABLE case_events            ENABLE ROW LEVEL SECURITY;
ALTER TABLE overlap_alerts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE case_links             ENABLE ROW LEVEL SECURITY;
ALTER TABLE dismissed_pairs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_events           ENABLE ROW LEVEL SECURITY;
ALTER TABLE roster_versions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE roster_rows            ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_attempts  ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- Helper function: get the active role for the current authenticated user
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION current_user_role() RETURNS TEXT AS $$
  SELECT role FROM role_assignments
  WHERE user_id = auth.uid()
    AND revoked_at IS NULL
  ORDER BY granted_at DESC
  LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION current_user_institution() RETURNS UUID AS $$
  SELECT institution_id FROM role_assignments
  WHERE user_id = auth.uid()
    AND revoked_at IS NULL
  ORDER BY granted_at DESC
  LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION current_user_bureau() RETURNS TEXT AS $$
  SELECT bureau FROM role_assignments
  WHERE user_id = auth.uid()
    AND revoked_at IS NULL
  ORDER BY granted_at DESC
  LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION current_user_region() RETURNS TEXT AS $$
  SELECT region FROM role_assignments
  WHERE user_id = auth.uid()
    AND revoked_at IS NULL
  ORDER BY granted_at DESC
  LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ═══════════════════════════════════════════════════════════════════════════
-- COMPLAINTS — the most critical table
-- ═══════════════════════════════════════════════════════════════════════════

-- Students see ONLY their own complaints
CREATE POLICY "student_own_complaints_select" ON complaints
  FOR SELECT USING (
    current_user_role() = 'student'
    AND submitted_by = auth.uid()
  );

-- Bureau officers see cases assigned to their Bureau
CREATE POLICY "bureau_officer_complaints_select" ON complaints
  FOR SELECT USING (
    current_user_role() IN ('bureau_officer', 'pgrc_triage_officer')
    AND assigned_bureau = current_user_bureau()
  );

-- Bureau heads see all cases in their Bureau
CREATE POLICY "bureau_head_complaints_select" ON complaints
  FOR SELECT USING (
    current_user_role() = 'bureau_head'
    AND assigned_bureau = current_user_bureau()
  );

-- Regional officers see cases for institutions in their region
CREATE POLICY "regional_officer_complaints_select" ON complaints
  FOR SELECT USING (
    current_user_role() = 'regional_officer'
    AND institution_id IN (
      SELECT id FROM institutions WHERE region = current_user_region()
    )
  );

-- College management: referred cases only, NEVER management-involved cases
CREATE POLICY "college_management_complaints_select" ON complaints
  FOR SELECT USING (
    current_user_role() = 'college_management'
    AND institution_id = current_user_institution()
    AND status IN ('referred','awaiting_response','under_examination','decision_recorded','closed')
    AND involves_management = FALSE   -- HARD BLOCK: management cases never visible here
  );

-- Faculty: only cases they are assigned to as participants
CREATE POLICY "faculty_complaints_select" ON complaints
  FOR SELECT USING (
    current_user_role() = 'faculty'
    AND id IN (
      SELECT complaint_id FROM participants
      WHERE user_id = auth.uid()
        AND removed_at IS NULL
    )
  );

-- Senior read-only roles: competent authority and ombudsperson
CREATE POLICY "senior_readonly_complaints_select" ON complaints
  FOR SELECT USING (
    current_user_role() IN ('competent_authority', 'ombudsperson', 'auditor', 'system_admin')
  );

-- Students can INSERT their own complaint (submitted_by enforced server-side too)
CREATE POLICY "student_submit_complaint" ON complaints
  FOR INSERT WITH CHECK (
    current_user_role() = 'student'
    AND submitted_by = auth.uid()
  );

-- PGRC triage officers can INSERT (on-behalf-of intake)
CREATE POLICY "pgrc_intake_complaint" ON complaints
  FOR INSERT WITH CHECK (
    current_user_role() = 'pgrc_triage_officer'
  );

-- Officers can UPDATE cases assigned to their Bureau
CREATE POLICY "officer_update_complaint" ON complaints
  FOR UPDATE USING (
    current_user_role() IN ('pgrc_triage_officer', 'bureau_officer')
    AND assigned_bureau = current_user_bureau()
  );

-- Bureau heads can update any case in their Bureau
CREATE POLICY "bureau_head_update_complaint" ON complaints
  FOR UPDATE USING (
    current_user_role() = 'bureau_head'
    AND assigned_bureau = current_user_bureau()
  );

-- NO DELETE policy on complaints — hard deny for all roles

-- ═══════════════════════════════════════════════════════════════════════════
-- CASE EVENTS — append only, read scoped by complaint access
-- ═══════════════════════════════════════════════════════════════════════════

CREATE POLICY "case_events_select" ON case_events
  FOR SELECT USING (
    -- Can read events if you can read the parent complaint
    complaint_id IN (SELECT id FROM complaints)
  );

CREATE POLICY "case_events_insert" ON case_events
  FOR INSERT WITH CHECK (
    -- Anyone who can read the complaint can append an event (app enforces actor/role logic)
    complaint_id IN (SELECT id FROM complaints)
  );
-- UPDATE and DELETE already revoked via REVOKE statements in migration 007

-- ═══════════════════════════════════════════════════════════════════════════
-- USERS — read own profile; officers read within scope
-- ═══════════════════════════════════════════════════════════════════════════

CREATE POLICY "users_read_own" ON users
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "officers_read_users" ON users
  FOR SELECT USING (
    current_user_role() IN (
      'pgrc_triage_officer','bureau_officer','bureau_head',
      'regional_officer','competent_authority','auditor','system_admin'
    )
  );

CREATE POLICY "users_update_own" ON users
  FOR UPDATE USING (id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════
-- ROLE ASSIGNMENTS — only auditors/admins can see all; others see own
-- ═══════════════════════════════════════════════════════════════════════════

CREATE POLICY "role_assignments_own" ON role_assignments
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "role_assignments_admin" ON role_assignments
  FOR SELECT USING (
    current_user_role() IN ('auditor','system_admin','bureau_head','competent_authority')
  );

CREATE POLICY "role_assignments_admin_insert" ON role_assignments
  FOR INSERT WITH CHECK (
    current_user_role() IN ('system_admin','auditor')
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- AFFILIATIONS — students see own; AICTE triage sees all for verification
-- ═══════════════════════════════════════════════════════════════════════════

CREATE POLICY "affiliations_own" ON affiliations
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "affiliations_triage_select" ON affiliations
  FOR SELECT USING (
    current_user_role() IN ('pgrc_triage_officer','auditor','system_admin','bureau_head')
  );

-- College management can see roster data but NOT complaint text
CREATE POLICY "affiliations_college_roster" ON affiliations
  FOR SELECT USING (
    current_user_role() = 'college_management'
    AND institution_id = current_user_institution()
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS — users see only their own
-- ═══════════════════════════════════════════════════════════════════════════

CREATE POLICY "notifications_own" ON notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "notifications_mark_read" ON notifications
  FOR UPDATE USING (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════
-- OVERLAP ALERTS — AICTE officers only
-- ═══════════════════════════════════════════════════════════════════════════

CREATE POLICY "overlap_alerts_officers" ON overlap_alerts
  FOR SELECT USING (
    current_user_role() IN (
      'pgrc_triage_officer','bureau_officer','bureau_head',
      'regional_officer','competent_authority','auditor','system_admin'
    )
  );

CREATE POLICY "overlap_alerts_update_officers" ON overlap_alerts
  FOR UPDATE USING (
    current_user_role() IN ('pgrc_triage_officer','bureau_officer','bureau_head')
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- AUDIT EVENTS — auditors and system_admin only; others see nothing
-- ═══════════════════════════════════════════════════════════════════════════

CREATE POLICY "audit_events_admin_select" ON audit_events
  FOR SELECT USING (
    current_user_role() IN ('auditor','system_admin')
  );

-- INSERT allowed for authenticated users (app writes audit events on every action)
CREATE POLICY "audit_events_insert" ON audit_events
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ═══════════════════════════════════════════════════════════════════════════
-- ROSTER tables — college management uploads; AICTE triage verifies
-- ═══════════════════════════════════════════════════════════════════════════

CREATE POLICY "roster_versions_college_select" ON roster_versions
  FOR SELECT USING (
    (current_user_role() = 'college_management' AND institution_id = current_user_institution())
    OR current_user_role() IN ('pgrc_triage_officer','auditor','system_admin','bureau_head')
  );

CREATE POLICY "roster_versions_college_insert" ON roster_versions
  FOR INSERT WITH CHECK (
    current_user_role() = 'college_management'
    AND institution_id = current_user_institution()
  );

CREATE POLICY "roster_rows_select" ON roster_rows
  FOR SELECT USING (
    version_id IN (SELECT id FROM roster_versions)
  );

-- Evidence: scoped by complaint access
CREATE POLICY "evidence_select" ON evidence
  FOR SELECT USING (
    complaint_id IN (SELECT id FROM complaints)
  );

CREATE POLICY "evidence_insert" ON evidence
  FOR INSERT WITH CHECK (
    complaint_id IN (SELECT id FROM complaints)
    AND uploaded_by = auth.uid()
  );

-- Institutions: readable by all authenticated users (public profile data)
CREATE POLICY "institutions_authenticated_select" ON institutions
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Only admins can modify institution data
CREATE POLICY "institutions_admin_update" ON institutions
  FOR UPDATE USING (current_user_role() IN ('system_admin','auditor'));
