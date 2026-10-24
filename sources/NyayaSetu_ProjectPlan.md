# NyayaSetu — SIH 2026 Master Implementation Plan
### PS 26264 · AICTE · Regulation Bureau · Smart Automation

> **Project Name:** NyayaSetu (meaning "Bridge to Justice")
> **Internal Codename:** CaseBridge AI
> **Problem Statement ID:** 26264
> **Organisation:** AICTE — Regulation Bureau
> **Category:** Software · Theme: Smart Automation

---

## Table of Contents

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Portal Map — Who Exists, What They See](#2-portal-map)
3. [Authentication Design (Deep Dive)](#3-authentication-design)
4. [Phase Breakdown](#4-phase-breakdown)
   - Phase 0 — Freeze & Scaffold
   - Phase 1 — Foundation & Access Control
   - Phase 2 — AICTE Dashboard & Case Lifecycle
   - Phase 3 — Overlap Detection & AI Matching
   - Phase 4 — Feeder Portals (Student, Faculty, College)
   - Phase 5 — Notifications, OCR, Multilingual
   - Phase 6 — Reports, RAG, Hardening & Demo Polish
5. [Feature ↔ Portal Cross-Impact Matrix](#5-feature--portal-cross-impact-matrix)
6. [OCR Deep Dive](#6-ocr-deep-dive)
7. [Edge Cases & How to Avoid Them](#7-edge-cases)
8. [Database Schema Blueprint](#8-database-schema-blueprint)
9. [API Integration Map](#9-api-integration-map)
10. [UI/UX Philosophy](#10-uiux-philosophy)
11. [Demo Script (SIH Judging)](#11-demo-script)
12. [Cut List & Future Work](#12-cut-list--future-work)

---

## 1. System Architecture Overview

```
┌───────────────────────────────────────────────────────────────────────┐
│                          ONE Next.js App (Monorepo)                   │
│                                                                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌─────────────┐ │
│  │  Student PWA │ │ Faculty      │ │ College Mgmt │ │ AICTE Admin │ │
│  │  (Mobile 1st)│ │ Portal       │ │ Portal       │ │ Dashboard   │ │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬──────┘ │
│         │                │                │                │         │
│  ─────────────── Role-Based Route Guard (Next.js middleware) ───────  │
│         │                │                │                │         │
│  ┌──────▼────────────────▼────────────────▼────────────────▼──────┐  │
│  │               Shared Backend (Next.js API Routes / Fastify)     │  │
│  │                                                                 │  │
│  │  ┌──────────┐ ┌────────────┐ ┌──────────────┐ ┌────────────┐  │  │
│  │  │ Auth     │ │ Case       │ │ Notification │ │ Overlap    │  │  │
│  │  │ Module   │ │ Lifecycle  │ │ Policy       │ │ Detector   │  │  │
│  │  └──────────┘ └────────────┘ └──────────────┘ └────────────┘  │  │
│  │                                                                 │  │
│  │  ┌──────────┐ ┌────────────┐ ┌──────────────┐ ┌────────────┐  │  │
│  │  │ OCR      │ │ RAG Policy │ │ Reports &    │ │ Audit &    │  │  │
│  │  │ Service  │ │ Assistant  │ │ Analytics    │ │ Hash Chain │  │  │
│  │  └──────────┘ └────────────┘ └──────────────┘ └────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                             │                                         │
│                    ┌────────▼──────────┐                              │
│                    │   PostgreSQL       │                              │
│                    │ (Supabase/Neon)   │                              │
│                    │  + pgvector       │                              │
│                    │  + pg_trgm        │                              │
│                    │  + Row-Level Sec  │                              │
│                    └────────┬──────────┘                              │
│                             │                                         │
│         ┌───────────────────┼────────────────────┐                   │
│         ▼                   ▼                    ▼                    │
│   Object Storage      pg-boss / BullMQ     Realtime Channel          │
│   (Private S3/R2)     (Job Queue)          (SSE / Supabase RT)       │
└───────────────────────────────────────────────────────────────────────┘
```

### Key architectural decisions

| Decision | Choice | Why |
|---|---|---|
| Frontend framework | Next.js 14 (App Router) + TypeScript | SSR for AICTE dashboard, SSG for public pages, one codebase |
| Styling | Tailwind CSS + shadcn/ui | Consistent component library, not generic-looking |
| Database | PostgreSQL with Row-Level Security | Relational integrity, cross-Bureau joins, native RLS for tenant isolation |
| Auth | Supabase Auth (or Auth.js) | OTP, TOTP, session management, RLS integration |
| Realtime | Supabase Realtime or Server-Sent Events | Live dashboard updates without polling |
| AI | Pre-trained multilingual embeddings + pgvector | No custom training, explainable similarity |
| OCR | Tesseract.js (browser-side) | Document never leaves device until user confirms |
| Offline | PWA + Service Worker + IndexedDB | Student drafts, field notes |
| Jobs | pg-boss (Postgres-backed) | Deadline reminders, report generation, email retries |

---

## 2. Portal Map

There are **4 portals** sharing **1 backend** with role-based layouts. Each portal is a different set of Next.js pages protected by middleware.

---

### Portal 1 — Student / Alumnus (Mobile-First PWA)

**URL pattern:** `/student/*`
**Primary device:** Phone (360px first)
**Auth:** Email + Phone OTP (passwordless)

#### Features

| Feature | Description | Impact on other portals |
|---|---|---|
| **Onboarding wizard** | Register → email OTP → phone OTP → pick institution → affiliation type (current/alumnus) → proof upload (optional) | College portal sees new affiliation claim. AICTE triage queue sees unverified claims |
| **Complaint wizard** | Category picker, description (English/Hindi/Marathi or voice), evidence upload, urgency flag, confidentiality toggle, preview, submit | Lands in AICTE PGRC triage queue. Overlap detector runs immediately. Duplicate check runs before submit |
| **Pre-submit duplicate check** | "You already have a similar open complaint" — link to follow up | Prevents PGRC queue spam |
| **My cases** | Tracking ID, plain-language status timeline, next expected date, requests for clarification, message thread | All state comes from AICTE case events; no copy |
| **Post-closure feedback & appeal** | Rate outcome. Appeal eligibility computed from routing rules — NOT from the rating | Feeds AICTE disposal analytics |
| **Privacy centre** | What is stored, consent log, correct/erase verification documents | AICTE auditor sees what data exists |
| **Offline drafts** | IndexedDB save, sync on reconnect, evidence upload resume | Nothing syncs until live session confirmed |
| **Voice input** | Web Speech API / Bhashini for Hindi/Marathi transcription | Transcription stored as text alongside original voice note |

**What students CANNOT see:**
- Other students' cases
- AICTE officer notes or internal remarks
- Overlap alerts or Bureau assignments
- Identity of the investigation officer (name withheld, role shown)

---

### Portal 2 — Faculty / Committee Member

**URL pattern:** `/faculty/*`
**Primary device:** Phone + Laptop (hybrid layout)
**Auth:** Institutional email OTP, linked to college roster entry

#### Features

| Feature | Description | Impact on other portals |
|---|---|---|
| **Assigned-cases inbox** | ONLY cases personally assigned to them | College portal sees inbox state; AICTE sees assignment log |
| **Conflict-of-interest declaration** | On first open of any case; recuse triggers reassignment | College management must reassign; reason logged in audit trail |
| **Respond to case** | Factual response form, evidence upload, internal notes, hearing minutes | Student sees response summary (redacted if sensitive). AICTE officer sees full response |
| **Hearing scheduler** | Propose multiple dates → student and institution notified | Notification sent to student via email + in-app. College management sees scheduled hearing |
| **Workload view** | My open tasks, deadlines, overdue items | Bureau head at AICTE sees workload across the college |

**What faculty CANNOT see:**
- Other faculty members' cases or responses
- Cases where they have a conflict of interest (system blocks after recusal)
- AICTE internal overlap alerts
- Cases involving the faculty member themselves

---

### Portal 3 — College Management (Principal / Grievance Officer)

**URL pattern:** `/college/*`
**Primary device:** Laptop / Tablet
**Auth:** Email OTP + TOTP authenticator (MFA mandatory)

#### Features

| Feature | Description | Impact on other portals |
|---|---|---|
| **Institution profile** | AICTE permanent ID, SGRC committee roster, Ombudsperson contact, effective-date tracking | AICTE portal sees the same profile with full history |
| **Referred cases** | Assign to committee member, set internal deadline, submit official response + action-taken report | Faculty portal shows new assignment. AICTE officer reviews the submitted response |
| **Student roster upload (CSV)** | Versioned uploads, access-logged. Feeds affiliation verification | Students' verification status updates. AICTE auditor sees who uploaded what version |
| **Compliance view** | Monthly received/disposed/pending auto-report (mirrors AICTE 2017 directive) | AICTE senior management sees institution responsiveness score |
| **Pending ageing view** | Cases by age bucket | Feeds AICTE region-wise and institution-wise reports |

**HARD LIMITS — College portal cannot:**
- See cases where the complainant named the Principal or management (these are routed to AICTE-independent path)
- Modify or delete any case record
- Access cases before AICTE refers them
- Approve or deny verification disputes (these go to AICTE triage)

---

### Portal 4 — AICTE Dashboard (Multi-Role)

**URL pattern:** `/aicte/*`
**Primary device:** Desktop (1280–1920px), tablet for Regional Officers
**Auth:** Official email + TOTP; production = NIC/Government SSO

This is the **product's heart**. All sub-roles share the same portal with different home screens.

#### Sub-roles and their home screens

| Sub-Role | Home Screen | Key Powers |
|---|---|---|
| **PGRC Triage Officer** | Intake queue with verification badges | Verify, categorise, route (to college or Bureau), mark out-of-scope with reason and redirect |
| **Regulation Bureau Officer** | Cases needing regulatory action | Link to PGRC cases, record inspection/show-cause steps, raise overlap coordination |
| **Other Bureau/Cell Officer** | Only cases routed to them | Request transfer to another Bureau, add action steps |
| **Regional Office Officer** | Cases for institutions in their region | Offline field notes (stretch goal), regional report |
| **Bureau Head / Adviser** | Workload view + ageing | Reassign, approve transfers, escalate, see overdue cases across Bureau |
| **Competent Authority / Senior Management** | Read-only live dashboard | Institution risk view, scheduled reports — zero ability to modify cases |
| **Ombudsperson** | Appeal queue only | Decide appeals, record decision, case closes or returns |
| **Auditor / System Admin** | Audit log, role changes, configuration | Every config change requires a reason string; no case modification access |

#### AICTE dashboard features (PS requirements mapped 1:1)

| PS Requirement | Dashboard Feature |
|---|---|
| Total complaints/cases received | KPI tile — live count |
| Pending cases | KPI tile — filterable |
| Cases under process | KPI tile |
| Cases disposed | KPI tile + disposal rate trend |
| Cases transferred | KPI tile |
| Cases pending beyond prescribed timelines | KPI tile (red) + drill-down list |
| Institution-wise case status | Institution profile page with consolidated history |
| Bureau/Cell-wise workload | Bar chart per Bureau |
| **Overlap detection** | Alert centre — Coordination Required + Related Cases |
| Search by all 8 PS keys | Filter panel: Institution Name, AICTE ID, Case ID, Bureau, Region, Category, Status, Date range |
| Workflow and action history | Append-only event timeline per case |
| Generate reports | On-screen + CSV/Excel/PDF export |
| Alerts for pending/SLA breaching | Bell + email + escalation to Bureau head |

---

## 3. Authentication Design

> Authentication is the most important judge question. The answer must be layered, honest, and defensible.

### 3.1 — Login method per role

| Role | Primary Auth | Second Factor | Extra Control |
|---|---|---|---|
| Student / Alumnus | Email OR phone OTP (passwordless) | None for MVP | Device session list, new-login alert |
| Faculty | Institutional email OTP | None for MVP | Must match college roster entry; session tied to institution |
| College Management | Email OTP | **TOTP mandatory** (authenticator app) | Role granted only after AICTE-verified onboarding process |
| AICTE Officers | Official email OTP | **TOTP mandatory** | Role + Bureau + Region + purpose on every session token |
| Auditor / System Admin | Official email OTP | **TOTP mandatory** | IP allow-listing in production |

### 3.2 — Session token payload (JWT claims)

```typescript
{
  sub: "user-uuid",
  role: "pgrc_triage_officer",         // single role per session
  bureau: "PGRC",                       // null for student/faculty
  institution_id: null,                 // non-null for college mgmt & faculty
  region: "South-West",                 // for Regional Officers
  session_id: "uuid",                   // for revocation
  iat: 1234567890,
  exp: 1234567890 + 3600               // 1h, refresh silently, hard limit 8h
}
```

**Institution ID comes from the session, NEVER from the request body.** This is the single most important security rule. Any request that tries to pass an institution_id in the body is rejected; the server uses only the session claim.

### 3.3 — Affiliation verification (separate from complaint credibility)

This is a 5-step funnel, not a binary gate:

```
Step 1: Contact proof
  ↓  OTP verifies control of email/phone only
Step 2: Roster match
  ↓  Student enters enrollment number + programme
  ↓  System compares against college-uploaded CSV
Step 3: Document assist (OCR)
  ↓  ID card or fee receipt scanned client-side
  ↓  Fields extracted, shown to student for correction
  ↓  OCR output = reading aid ONLY, never proof of authenticity
Step 4: Outcome verdict (3 states)
  ├── Verified → normal routing
  ├── Needs review → goes to AICTE verification queue (NOT to college)
  └── Unable to verify → held at AICTE triage; urgency still respected
Step 5: Alumni path
  ↓  Historical roster or degree record
  ↓  If absent → manual review at AICTE
```

**Critical invariant:** verification status NEVER lowers complaint priority. A safety allegation from an "Unable to verify" account is still flagged urgent and reviewed by a human.

### 3.4 — Impersonation defence

| Attack | Defence |
|---|---|
| Someone claims to be a student | Must pass OTP + match unclaimed roster entry. One roster entry → one account. Second claim raises a **claim conflict** for manual review |
| Complaint filed with no roster match | Case marked **unverified**, held at AICTE triage, NOT auto-forwarded to college |
| Coordinated burst (many accounts, same wording, same hour) | Reviewer flag raised; accounts are not auto-blocked (false positive risk too high) |
| False statement in complaint | Recorded as evidence for the authorised process; the system never penalises anyone itself |
| Account takeover | Session revocation via device list; re-authentication required for sensitive actions |

### 3.5 — Confidentiality vs Anonymity

We offer **confidential handling** (identity hidden from college, visible to authorised AICTE officers only), NOT anonymity. This is correct because:
- AICTE's approval guidelines restrict anonymous complaints in regulatory processes
- CPGRAMS itself does not offer true anonymity
- A named officer must be accountable for the decision

### 3.6 — Row-Level Security (RLS) — the second lock

Every access control check happens **twice**:
1. Application layer (middleware + route guards)
2. PostgreSQL RLS policy layer

If the app has a bug that passes the wrong institution_id, RLS at the database level will reject the query. This is the second lock.

Example RLS policy:
```sql
-- Officers can only see cases assigned to their Bureau
CREATE POLICY "bureau_isolation" ON complaints
  USING (
    assigned_bureau = current_setting('app.current_bureau')::text
    OR auth.uid() IN (SELECT user_id FROM role_assignments WHERE role IN ('competent_authority', 'auditor'))
  );
```

---

## 4. Phase Breakdown

> Rule: Do NOT start a phase until the previous phase's "Done when" criterion passes.

---

### Phase 0 — Freeze & Scaffold (Week 1, before any code)

**Goal:** No ambiguity when coding starts.

**Deliverables:**
- [ ] Final database schema (freeze — no breaking changes after this)
- [ ] Permission matrix (role × resource × action — every cell filled)
- [ ] Case state-transition diagram (every valid transition, every invalid one)
- [ ] MVP feature list (what is Must Build vs Build If Stable vs Future)
- [ ] Wireframes for all 4 portals (hand-drawn or Figma low-fi)
- [ ] Seed data design (300 institutions, 10k roster rows, 1k complaints, 100 overlap scenarios)
- [ ] API contract (Zod schemas for every request/response)

**How portals connect at this phase:**
Nothing is built. The schema design ensures every portal reads the same tables. Define foreign keys and RLS policies on paper before any migration runs.

**Edge cases to freeze:**
- What happens if an institution is deleted? (Soft delete only — all cases must stay)
- What if a faculty member is removed from the roster mid-case? (Assignment stays, flag raised)
- What if a case category changes after assignment? (New event, old category preserved)
- What is the maximum file size for evidence uploads? (Define: 10MB per file, 5 files per case)

---

### Phase 1 — Foundation & Access Control (Week 1–2)

**Goal:** Auth works. Roles are enforced. No cross-institution leakage. Audit trail captures every action.

**Build list:**
1. PostgreSQL schema migration (all core tables)
2. Supabase Auth setup — OTP flow for students, TOTP for officers
3. JWT middleware with institution isolation
4. RLS policies on all tables
5. Role assignment management (admin grants roles)
6. Audit event table — append-only, with hash chain
7. Synthetic seed data (institutions, users, a handful of complaints)
8. Basic institution profile page (AICTE only, read-only)

**Done when:**
- Another institution's cases cannot be read or changed through the UI or the API
- A student account cannot access the AICTE dashboard route
- A college management account cannot see cases involving management
- Audit log captures every login, role assignment, and case view
- All access denied scenarios return 403, not 404 or 500

**How portals connect:**
Not yet. Phase 1 is infrastructure. The RLS policies here are what make every later phase safe.

**Critical edge cases (Phase 1):**

| Edge Case | Handling |
|---|---|
| Two devices logged in as same account | Both sessions valid; revoke via device list |
| Admin accidentally grants wrong role | Every role grant is an audit event; reversible, old event preserved |
| Database migration fails mid-run | Transactional migrations; rollback to previous state |
| TOTP device lost | Recovery codes at setup; officer contacts system admin for reset (logged) |
| Student uses VPN that blocks OTP SMS | Email OTP as fallback; never use phone-only |

---

### Phase 2 — AICTE Dashboard & Case Lifecycle (Week 2–3)

**Goal:** An AICTE officer can track a case from intake to recorded decision.

**Build list:**
1. Case creation (PGRC triage intake form)
2. All PS-required case fields: Case ID, receipt date, category, status, assigned Bureau/Cell, officer, last action, next action, last-action date, expected disposal date
3. Status transitions engine (state machine — explicit allowed transitions)
4. Case assignment to officer and Bureau
5. Transfer between Bureaus (with reason, logged)
6. Action history view (chronological, with timestamps and officer attribution)
7. AICTE dashboard — all 7 KPI tiles
8. Case table with the 8 PS search/filter keys
9. Institution profile page with consolidated case history
10. Deadline rules table (admin-editable, source-cited, not presented as official AICTE rules)
11. Deadline tracker (hourly job, sets deadline status)

**Done when:**
- PGRC triage officer creates a case, assigns it, transfers it to RB, RB officer records an action, case closes — full flow in demo
- All 8 filter keys return correct results
- Deadline track changes from "on track" → "nearing" → "overdue" with a seeded case

**How portals connect:**
At this phase, the AICTE portal is self-contained. The student and college portals are not built yet. The data model is already correct for them.

**State transition diagram (case lifecycle):**
```
Submitted → Under Triage → [Referred to College | Under Examination | Out of Scope]
Referred to College → Awaiting Response → Under Examination
Under Examination → Decision Recorded → Closed
Any state → Transferred (to another Bureau, stays in current state otherwise)
Any state → Escalated (Bureau head notified, escalation event logged)
Closed → [Appeal Submitted] (if appeal rule permits)
Appeal Submitted → Under Appeal Review → Appeal Decided → Closed
```

**Critical edge cases (Phase 2):**

| Edge Case | Handling |
|---|---|
| Officer tries to transition to invalid state | State machine rejects it at API level; UI disables invalid buttons |
| Two officers both assign themselves to the same case simultaneously | Optimistic locking (version column); second assignment sees conflict |
| Case transferred while awaiting college response | Transfer event logged; college still sees the case; new Bureau officer notified |
| Institution ID not found during case creation | Intake must select from the institution master list; freetext institution name is not allowed |
| Expected disposal date passes with no action | Hourly job moves deadline to "overdue"; escalation event created; Bureau head notified |

---

### Phase 3 — Overlap Detection & AI Matching (Week 3–4)

**Goal:** Seeded overlaps are found. False matches are dismissed with reasons.

#### Two separate alerts (this distinction is the PS's core ask)

**Alert 1 — Cross-Bureau Coordination Required (deterministic, instant)**
- Trigger: institution has open cases in 2+ Bureaus/Cells
- Logic: pure SQL — `GROUP BY institution_id HAVING COUNT(DISTINCT assigned_bureau) > 1`
- Shown as: "Potential Overlapping Cases – Coordination Required" (exact PS wording)
- Does NOT call the complaints duplicates
- Fires on every new case creation or Bureau change

**Alert 2 — Potential Related Cases (semantic, async)**
- Trigger: same institution has multiple cases
- Scoring: weighted sum of 6 factors (each shown in UI):
  1. Category match (0 or 1)
  2. Text embedding cosine similarity (0–1, multilingual model)
  3. Date proximity (exponential decay)
  4. Shared named entities (programme, person role, building)
  5. Identical attachment hash
  6. Different-Bureau flag (bonus weight)
- Threshold: configurable; tune using precision/recall on synthetic set
- Shown as: "Match strength: 73% — Potential Related Cases"

**Officer workflow:**
```
Alert appears in Alert Centre
       ↓
Officer opens both cases side by side
       ↓
UI shows: each factor as a row with its contribution
          matching phrases highlighted
          the two complaints side by side
       ↓
Officer chooses:
  ├── Link cases (pick lead Bureau, add coordination note)
  └── Dismiss (reason required, same pair never re-alerts)
```

**Build list:**
1. `pg_trgm` for institution name fuzzy matching
2. `pgvector` extension and embedding storage column on complaints table
3. Background job to compute embeddings on new complaint text (on creation)
4. Overlap alert computation job (runs on case creation and Bureau change)
5. Related-case scoring function (SQL + embedding cosine)
6. Alert centre UI (both alert types, filterable)
7. Case comparison view (side-by-side, factor breakdown, highlighted phrases)
8. Link/dismiss workflow with reason capture
9. Dismissed pairs table (so same pair never re-alerts)
10. Labelled synthetic test set (150+ pairs, including hard cases)
11. Precision/recall measurement script

**Done when:**
- All seeded cross-Bureau overlaps raise Alert 1
- The seeded "same fee complaint worded differently" pair raises Alert 2
- A seeded "different issue, same college" pair raises Alert 1 but NOT Alert 2
- Officer links two cases; both histories stay separate; coordination note visible
- Officer dismisses a pair with a reason; same pair never re-alerts

**Edge cases (Phase 3):**

| Edge Case | Handling |
|---|---|
| Typo in institution name ("IIT Bombay" vs "IIT Bombai") | `pg_trgm` fuzzy match + human confirmation before linking |
| Same institution name, different cities | Always use AICTE Permanent ID as the true key; name is display only |
| Alert fires on a case that is already closed | Only alert on open cases (filter in the alert query) |
| Embedding API is down | Queue embedding computation for retry; Alert 2 degrades gracefully (no embedding → no Alert 2 until computed) |
| Officer dismisses an alert but new evidence makes it relevant again | Dismissed alerts can be reopened by a Bureau head with a reason |
| Two complaints in the same Bureau (not cross-Bureau) | Alert 2 still fires if similarity is high; Alert 1 does not fire (same Bureau) |

---

### Phase 4 — Feeder Portals (Week 4–5)

**Goal:** One case flows through all four portals with correct permissions.

**Build list:**

**Student portal:**
1. Registration + OTP flow (email + phone)
2. Institution picker (search from master list)
3. Affiliation claim (enrollment number + programme)
4. Roster match (compare against CSV rows)
5. Complaint wizard (all fields, urgency flag, confidentiality toggle)
6. Pre-submit duplicate check
7. My cases page (tracking timeline)
8. Clarification request / message thread
9. Post-closure feedback form
10. Appeal submission (if rule permits)
11. Privacy centre (consent log, document deletion request)
12. Offline draft (IndexedDB, PWA service worker)

**Faculty portal:**
1. Institutional email OTP login + roster link
2. Assigned cases inbox
3. Conflict-of-interest declaration on first open
4. Recusal flow (triggers reassignment at college portal)
5. Respond form (factual response, evidence upload, internal notes)
6. Hearing scheduler (date proposal → notification to student + college)
7. Workload view (open tasks, deadlines)

**College management portal:**
1. TOTP-protected login
2. Institution profile (AICTE ID, committee roster)
3. Referred cases (from PGRC; assign to faculty member)
4. Internal deadline setting
5. Official response submission + action-taken report
6. Student roster upload (CSV, versioned, access-logged)
7. Compliance view (monthly auto-report)
8. Pending ageing view

**Done when:**
- Demo flow works: Student submits → AICTE receives → PGRC refers to college → College assigns to faculty → Faculty responds → AICTE closes → Student sees status update live
- An unassigned faculty account cannot open any case (tested)
- College management cannot see cases involving management (tested)
- Roster upload triggers re-verification for pending affiliation claims

**Cross-portal impact (Phase 4):**

Every action in Phase 4 is an event in the shared `case_events` table. No data is copied between portals. The UI for each portal queries the same tables with its role's RLS policy applied.

**Critical edge cases (Phase 4):**

| Edge Case | Handling |
|---|---|
| Student submits complaint about the very college they're enrolled in — involving the Principal | Complaint is routed away from the college portal entirely; AICTE handles it on the independent path |
| Faculty member is also a complainant in a different case | Those are separate accounts; no cross-contamination |
| College uploads a new roster that removes a verified student | Flag the student's affiliation as "needs re-verification"; do NOT auto-revoke complaint |
| Student complaint is in Hindi; officer UI is in English | Translation shown alongside original; original is the authoritative record |
| Student submits 10 complaints in one hour | Rate limit fires; reviewer flag raised; complaints are NOT auto-rejected |
| Offline draft syncs after 3 days | Server validates, checks for duplicates, and confirms the complaint date as the server-receipt time (not the draft timestamp) |

---

### Phase 5 — Notifications, OCR, Multilingual (Week 5–6)

**Goal:** Right recipients only. An OCR failure has a safe fallback.

**Build list:**

**Notifications:**
1. Event → policy table lookup → recipient resolution at send time
2. Email queue (BullMQ or pg-boss) with retries and idempotency key
3. In-app bell icon (unread count, list of notifications)
4. Web Push for PWA (student deadlines, action-needed)
5. Sensitive case rule: complaint against Principal → notification recipients come only from AICTE/independent path
6. Notification preferences (per user, per type, per language)
7. Notification never contains complaint text — links to authenticated portal only

**OCR pipeline:**
1. Tesseract.js loaded in browser (no document sent to server before user confirms)
2. Student uploads ID card or fee receipt image
3. Tesseract extracts text fields
4. UI shows extracted fields side by side with the image
5. Confidence score shown per field; low confidence fields highlighted
6. Student corrects any errors in a form
7. Corrected data submitted, not raw OCR output
8. If OCR fails entirely → manual entry fallback (always available)
9. OCR output stored separately from verified fields (for audit trail)

**Multilingual:**
1. i18n setup (next-intl or react-i18next)
2. English templates for all notification types
3. Hindi templates for all notification types
4. Marathi templates (stretch goal — add if time permits)
5. Language selector in user profile
6. All DB records store original language + ISO code
7. Bhashini API integration (mock for MVP, labelled as such) for voice transcription

**Done when:**
- A deadline-approaching notification reaches the student (email + in-app) but NOT the college officer for that case
- An OCR failure on an ID card does not block complaint submission (fallback form available)
- Hindi text complaint is stored and displayed correctly throughout the lifecycle
- A sensitive case notification does not appear in the college management portal's bell icon

**Critical OCR edge cases:**

| Edge Case | Handling |
|---|---|
| Image is too dark / blurry | Tesseract returns low confidence; entire field highlighted; manual entry prompted |
| Student uploads a PDF instead of image | Convert first page to image client-side (pdf.js) before passing to Tesseract |
| OCR extracts wrong enrollment number | User must confirm every extracted field; system NEVER auto-populates without user review |
| Tesseract language pack not loaded (offline) | OCR is skipped; manual entry form shown immediately |
| Student uploads a doctored ID | OCR cannot detect this; system records what was uploaded + what was extracted; human reviewer sees both; complaint marked "needs review" |
| Sensitive data in OCR output (Aadhaar number) | Never extract or store Aadhaar. If detected (pattern match), redact and warn user |

---

### Phase 6 — Reports, RAG, Hardening & Demo Polish (Week 6–7)

**Goal:** Scripted demo is repeatable. Every integration is labelled real or simulated.

**Build list:**

**Reports:**
1. All 8 PS reports as saved queries with filters
2. On-screen charts (Recharts or ECharts)
3. CSV export (all reports)
4. Excel export (ExcelJS)
5. PDF export (server-side render)
6. Scheduled monthly report (pg-boss job → generate → store → email Bureau heads)
7. Report scope respects viewer's role (Regional Officer sees only their region)

**RAG Policy Assistant:**
1. Corpus: AICTE APH 2024–27, AICTE grievance notifications, UGC 2023 regulations, CPGRAMS guidelines
2. Chunk by section, store embeddings in `policy_chunks`
3. Query: retrieve top-k passages by embedding cosine → generate answer from passages only
4. UI shows answer + citations (section, document name, page)
5. "Not found" abstention when top passages are below relevance threshold
6. RAG NEVER answers "is this complaint valid?" — scoped to procedure questions only

**Hardening:**
1. Playwright e2e test suite covering the 5-minute demo script exactly
2. Vitest unit tests for state machine, scoring function, routing logic
3. k6 load test: 1000 concurrent AICTE dashboard loads, report numbers
4. Security headers (CSP, HSTS, X-Frame-Options)
5. Dependency scan (npm audit)
6. Malware scan on file uploads (ClamAV or VirusTotal API)
7. All seed data labelled "DEMO" in the UI

**Demo polish:**
1. Demo accounts pre-seeded (student, faculty, college officer, PGRC officer, RB officer, senior management)
2. All demo integrations labelled: "Real: Tesseract OCR" / "Simulated: Bhashini API" / "Mock: DigiLocker"
3. Demo can be reset to clean state in one command
4. 5-minute script tested and timed

---

## 5. Feature ↔ Portal Cross-Impact Matrix

| Event (Who Does It) | Student Portal | Faculty Portal | College Portal | AICTE Portal |
|---|---|---|---|---|
| Student submits complaint | Gets case ID, status "Submitted" | Nothing | Nothing until referred | Lands in PGRC triage queue; duplicate + overlap check runs |
| PGRC refers to college | Status "Referred to institution", 15-day target shown | Notified only if assigned | Grievance officer sees it; assigns a member | Case stays visible; deadline clock starts |
| Faculty recuses (conflict of interest) | Nothing visible | Case leaves their inbox | Must reassign; reason logged | Visible in audit trail |
| College submits response | Sees response summary (redacted) | Response attributed to them | Action-taken report attached | Officer reviews; can return for clarification |
| **Overlap detected (RB + PGRC on same institution)** | Not told (unless their case is directly affected) | Not shown | Shown only if institution-level action needed | Alert to both Bureaus; lead Bureau chosen; cases linked, histories stay separate |
| Deadline nears or passes | Reminder, then "delayed" notice | Task reminder | Reminder to coordinator | Escalation to Bureau head; appears in beyond-timeline KPI tile |
| Decision recorded | Decision notice + rating prompt | Notified if involved | Notified | Case closes; disposal-rate stats update |
| Student rates "Poor" and appeals | Appeal tracked if rule allows | Only if process involves them | Informed if permitted | Goes to Ombudsperson or appellate queue only if configured rule is met |
| Roster uploaded or changed | Re-verification may be prompted | Nothing | Roster version logged | Auditor sees who changed what |
| Officer opens a sensitive record | Nothing | Nothing | Nothing | Audit event: who opened, when, why (reason required) |

---

## 6. OCR Deep Dive

OCR is a **convenience tool, never a verification tool.** Every design decision reinforces this.

### 6.1 — Why client-side only?

Tesseract.js runs entirely in the browser. The document never leaves the device until the user consciously clicks "Submit". This:
- Removes a potential data breach vector
- Aligns with DPDP 2025 data minimisation principles
- Lets us handle OCR even when the server is slow

### 6.2 — Supported document types

| Document | Fields to Extract | Confidence Notes |
|---|---|---|
| College ID card | Name, Enrollment No., Programme, Year, Institution name | Enrollment No. is primary target; low confidence on handwritten fields |
| Fee receipt | Name, Enrollment No., Programme, Amount, Date | Good for printed receipts; poor for handwritten |
| Degree certificate | Name, Programme, Year of passing | Alumni verification path |
| Aadhaar card | **NEVER extract.** Redact and warn user. | DPDP compliance — no Aadhaar in system |

### 6.3 — Confidence thresholds

```
Tesseract confidence per word (0–100):
  ≥ 80: Green — auto-populated in form field
  50–79: Yellow — pre-populated but highlighted for user review
  < 50: Red — field left blank, manual entry required
  Entire word set avg < 40: OCR skipped, fallback form shown
```

### 6.4 — The correction flow

```
1. Student uploads image
2. Client-side preprocessing: resize to ≤ 2000px, grayscale, contrast boost
3. Tesseract runs: extracts words with confidence
4. UI renders: image on left, editable form fields on right
5. Each field shows confidence badge and allows edit
6. Student corrects all fields and clicks "Use these details"
7. Corrected data (not raw OCR output) is sent to the server
8. Server stores: { ocr_raw: "...", user_corrected: "...", ocr_confidence: 0.72 }
9. Human reviewer can see both versions
```

### 6.5 — What OCR feeds

OCR feeds the **affiliation verification wizard** only. It is not used for:
- Evidence upload review (human officer reviews evidence)
- Complaint content (user types/speaks their complaint)
- Any automated decision

### 6.6 — Failure modes and fallbacks

| Failure | Fallback |
|---|---|
| Tesseract fails to load (network offline, blocked) | Manual entry form shown immediately |
| Image too small (<300px) | Warning: "Image too small for extraction; please upload a clearer photo" |
| No text detected | Fallback form, no error blocking submission |
| Aadhaar pattern detected | Field redacted, user warned: "Please upload an ID without Aadhaar number" |
| PDF uploaded (not image) | First page converted to PNG using pdf.js, then passed to Tesseract |

---

## 7. Edge Cases

> These are the cases judges will ask about. Have a specific, defensible answer for each.

### 7.1 — Authentication edge cases

| Case | Exact Handling |
|---|---|
| Student's college is not in AICTE master list | Institution picker won't show it; complainant contacts AICTE helpdesk (link provided); complaint not possible for unrecognised institutions |
| Faculty account logs in from a different institution | Session token has institution_id; RLS blocks all cases for a different institution |
| College management logs in during a roster upload by another officer | Versioned uploads; last-writer-wins for the roster; all versions stored; audit log shows both |
| TOTP device stolen | Officer calls admin; admin revokes session; new TOTP setup required; all events logged |
| Student uses someone else's enrollment number | If that number is already claimed by another account, a claim conflict is raised for AICTE manual review; the attacker's account is not given access |

### 7.2 — Overlap detection edge cases

| Case | Exact Handling |
|---|---|
| Same institution, completely different issues (fee vs ragging) | Alert 1 fires (cross-Bureau). Alert 2 does NOT fire (low similarity). Both are correct |
| Complaint is about a sister institution with very similar name | `pg_trgm` match with human confirmation; AICTE Permanent ID is the true gate; similar names are flagged for human to confirm |
| Overlap alert fires but both cases are already assigned to the same lead officer | Alert still fires; officer can dismiss with reason "already being coordinated" |
| A linked case is closed; the other is still open | Re-evaluate overlap status; if link was the reason for a routing decision, Bureau head is notified |
| Dismissed overlap becomes relevant again (new information) | Bureau head can reopen a dismissed alert with a reason; the history of the original dismissal is preserved |

### 7.3 — Case lifecycle edge cases

| Case | Exact Handling |
|---|---|
| Complainant withdraws the complaint | New "Withdrawn by complainant" event; case moves to closed; withdrawal reason recorded; no automatic reopening without new submission |
| Institution is under active litigation for the same matter | "Out of scope — sub judice" classification; redirect text provided (mirroring CPGRAMS exclusion rules) |
| Two Bureaus disagree on who should be lead | Escalation to Bureau head; decision with reason logged; both case histories remain |
| Case referred to college, but college does not respond within deadline | AICTE triage officer is notified; case transitions to "Awaiting Response — Overdue"; AICTE can take the case to direct examination |
| Complaint involves both a fee issue and a ragging allegation | Multi-category complaint; urgent category (ragging) governs priority and routing; secondary category tracked separately |
| An officer is transferred to a different Bureau | Active case assignments flagged; Bureau head reassigns each case; previous officer's actions remain in history under their name |

### 7.4 — Data integrity edge cases

| Case | Exact Handling |
|---|---|
| Duplicate complaint submitted (same student, same text, same day) | Pre-submit client-side check (hash of description) + server-side deduplication; user shown "you already submitted this" with link to existing case |
| Evidence file is corrupt | Upload validation: MIME type check, file size limit, basic format verification; corrupt files rejected with error message |
| Large file upload (video evidence) | Files > 10MB rejected with an error suggesting compression; no streaming upload in MVP |
| Case event hash chain is broken | Daily integrity check job; if chain is broken, alert sent to auditor with the specific event ID; investigation required |
| Rollback of a migration corrupts case_events | Case events table has no foreign key updates allowed; migration rollback is tested in staging before production |

---

## 8. Database Schema Blueprint

```sql
-- Core identity
institutions (id PK, aicte_permanent_id UNIQUE, name, region, address, type, status, created_at)
users (id PK, email, phone, role, institution_id FK, bureau, region, is_active, created_at)
role_assignments (id PK, user_id FK, role, bureau, institution_id, granted_by FK, granted_at, revoked_at, reason)

-- Affiliation
affiliations (id PK, user_id FK, institution_id FK, type, enrollment_no, programme, year, status ENUM[verified,needs_review,unable_to_verify], claimed_at)
verification_attempts (id PK, affiliation_id FK, method ENUM[roster,document,manual], ocr_raw JSONB, user_corrected JSONB, ocr_confidence FLOAT, outcome, reviewed_by FK, reviewed_at)
roster_versions (id PK, institution_id FK, uploaded_by FK, uploaded_at, row_count, file_path, is_active)
roster_rows (id PK, version_id FK, enrollment_no, name, programme, year, is_claimed)

-- Cases
complaints (
  id PK, case_id UNIQUE (human-readable), institution_id FK,
  submitted_by FK, submitted_at, receipt_date,
  category, secondary_category,
  description_text, description_language,
  description_embedding VECTOR(768),       -- pgvector
  status ENUM[...], verification_status, coordination_status, deadline_status, appeal_status, urgency_status,
  assigned_bureau, assigned_officer FK,
  last_action_at, expected_disposal_at,
  is_confidential, involves_management, is_demo,
  version INT DEFAULT 1                    -- for optimistic locking
)
participants (id PK, complaint_id FK, user_id FK, role ENUM[complainant,officer,faculty,auditor], added_at, removed_at)
evidence (id PK, complaint_id FK, uploaded_by FK, file_path, mime_type, size_bytes, hash_sha256, malware_scanned_at, malware_clean, uploaded_at, is_ocr_source)

-- Append-only event log (hash-chained)
case_events (
  id PK, complaint_id FK, event_type, actor_id FK, actor_role, bureau,
  old_state JSONB, new_state JSONB,
  remarks, document_ids TEXT[],
  event_at TIMESTAMP,
  prev_event_hash TEXT,
  event_hash TEXT  -- SHA256(prev_hash + event_type + actor_id + event_at + payload)
)

-- Overlap detection
overlap_alerts (id PK, institution_id FK, alert_type ENUM[coordination,related], status ENUM[open,linked,dismissed], complaint_ids INT[], triggered_at, reviewed_by FK, reviewed_at, review_reason)
case_links (id PK, alert_id FK, complaint_a_id FK, complaint_b_id FK, lead_bureau, link_reason, linked_by FK, linked_at)
dismissed_pairs (id PK, complaint_a_id FK, complaint_b_id FK, dismissed_by FK, dismissed_at, reason, can_reopen BOOL)

-- Deadlines
deadline_rules (id PK, name, route, category, days_to_deadline, source_citation, effective_from, approved_by, is_active)
deadlines (id PK, complaint_id FK, rule_id FK, due_at, status ENUM[on_track,nearing,overdue,paused], paused_reason, last_checked_at)

-- Notifications
notification_policies (id PK, event_type, recipient_role, channel, template_key, is_active)
notifications (id PK, user_id FK, complaint_id FK, event_type, channel, status, idempotency_key UNIQUE, sent_at, read_at)

-- RAG
policy_chunks (id PK, document_name, section, page, content_text, embedding VECTOR(768), indexed_at)

-- Reports
report_runs (id PK, report_type, requested_by FK, params JSONB, status, file_path, generated_at)

-- Audit
audit_events (id PK, actor_id FK, action, resource_type, resource_id, old_value JSONB, new_value JSONB, ip_address, session_id, reason, event_at)
```

---

## 9. API Integration Map

### Real integrations (built and working)

| Integration | What it does | Risk |
|---|---|---|
| **Supabase Auth** | OTP and TOTP authentication, session management | Dependency on external service; local fallback: Auth.js |
| **PostgreSQL (Supabase/Neon)** | Primary database | Data residency concern; use Indian-region deployment |
| **Tesseract.js** | Client-side OCR for ID cards and fee receipts | Accuracy limitation; always provide manual fallback |
| **pgvector** | Semantic similarity search for overlap detection | Requires PostgreSQL extension; supported by Supabase/Neon |
| **pg_trgm** | Fuzzy institution name matching | Standard Postgres extension; always available |
| **ExcelJS** | Excel report export | No external API; runs server-side |
| **jsPDF / Puppeteer** | PDF report export | Server-side rendering |
| **BullMQ + Redis / pg-boss** | Job queue for emails, reminders, embeddings | pg-boss is simpler (Postgres-only, no Redis needed) |

### Simulated integrations (labelled in UI as "Simulated")

| Integration | What it should do | Demo approach |
|---|---|---|
| **Bhashini API** | Hindi/Marathi voice transcription and translation | Mock API that returns a hardcoded transcript; label "Simulated: Bhashini" |
| **AICTE Institution Master API** | Live institution data from AICTE | CSV import of institution list; label "Data source: AICTE public list (static)" |
| **Email provider (Resend/SendGrid)** | Transactional emails | Use Resend sandbox; real emails to demo accounts |
| **Web Push VAPID** | Browser push notifications | Real implementation; limited to Chrome/Android |

### Future integrations (labelled as "Future Work")

| Integration | Why deferred |
|---|---|
| **NIC SSO / eGov SSO** | Requires government partner onboarding |
| **DigiLocker / APAAR** | Requires partner onboarding; shown as mock only |
| **SMS / WhatsApp** | Requires sender registration in India; DLT compliance |
| **ClamAV / VirusTotal** | Malware scan on uploads; add in Phase 6 hardening |
| **External audit hash anchor** | Chain head hash written to external location daily |

### API keys and secrets management

```
.env.local (never committed):
  DATABASE_URL=
  SUPABASE_URL=
  SUPABASE_ANON_KEY=
  SUPABASE_SERVICE_ROLE_KEY=
  NEXTAUTH_SECRET=
  RESEND_API_KEY=
  REDIS_URL= (if using BullMQ)
  VAPID_PUBLIC_KEY=
  VAPID_PRIVATE_KEY=

All secrets accessed only server-side.
No API key ever sent to the client.
```

---

## 10. UI/UX Philosophy

### Design principles (not AI slop)

1. **Information density, not visual noise.** The AICTE dashboard shows data. Don't fill white space with decorative elements. Every pixel must carry information.
2. **Status at a glance.** Case status, deadline status, and overlap alerts must be readable without interaction — colour + icon + text label (never colour alone, for accessibility).
3. **Hierarchy through spacing, not cards.** Nested cards create cognitive load. Use whitespace, typographic hierarchy, and dividers instead.
4. **Mobile-first for students, desktop-first for AICTE.** These are genuinely different interfaces, not the same thing at different breakpoints.
5. **No animations that delay information.** Micro-animations on hover and transitions between states are fine. Loading spinners instead of content are not.

### Typography

```
Primary: Inter (Google Fonts) — body, labels, data
Display: Inter Bold / Semibold — headings only (not decorative)
Monospace: JetBrains Mono — case IDs, tracking numbers, hash values
Size scale: 12 / 14 / 16 / 20 / 24 / 32 px
```

### Colour system

```
Neutral: Slate (shadcn default) — all body and background
Status colours (semantic, not decorative):
  Submitted:        Blue-500 (#3B82F6)
  Under Process:    Amber-500 (#F59E0B)
  Overdue:          Red-600 (#DC2626)
  Disposed:         Green-600 (#16A34A)
  Escalated:        Orange-500 (#F97316)
  Overlap Alert 1:  Red-700 (#B91C1C) — Coordination Required
  Overlap Alert 2:  Amber-600 (#D97706) — Potential Related Cases
  Out of Scope:     Slate-500 (#64748B)
```

### Responsive breakpoints

| Breakpoint | Pixels | Target |
|---|---|---|
| xs | 360 | Student phone (primary) |
| sm | 640 | Large phone |
| md | 768 | Tablet (faculty) |
| lg | 1280 | Laptop (college management, AICTE) |
| xl | 1920 | Large monitor (AICTE senior management) |

Tables below 768px become stacked cards. Charts always have a text summary alongside.

### Accessibility

- WCAG 2.1 AA contrast ratios minimum
- All interactive elements keyboard-navigable
- Screen-reader labels on icons (not just tooltips)
- No information conveyed by colour alone
- Focus indicators visible and high-contrast

---

## 11. Demo Script (SIH Judging — 5 Minutes)

> Practice this until it is exactly 5 minutes. Every integration should be labelled real or simulated on screen during the demo.

**Setup:** 4 browser tabs open before judges arrive: Student (mobile viewport), AICTE PGRC Officer, AICTE RB Officer, Senior Management Dashboard.

| Time | Action | What to say |
|---|---|---|
| 0:00–0:30 | Open student tab (mobile viewport). Student files a complaint about a fee refund issue at "Apex Institute of Technology". Category: Financial. Urgency flag: No. | "A student submits a complaint. Watch the tracking ID appear instantly." |
| 0:30–1:00 | Switch to PGRC Officer tab. The new case is in the intake queue with a verification badge. | "The PGRC triage officer sees it in real time. Verification status is shown separately from complaint credibility." |
| 1:00–1:30 | On the PGRC tab: an existing RB case about Apex Institute is already open (pre-seeded). The red **Coordination Required** alert appears. Open the alert. | "This is the core of the problem statement. 'Potential Overlapping Cases – Coordination Required.' The same institution is being handled by two Bureaus." |
| 1:30–2:30 | Open the case comparison view. Show Alert 2 (Potential Related Cases) with the factor breakdown: same category (fee), 81% embedding similarity, same dates. Both complaints side by side with matching phrases highlighted. | "The AI doesn't decide anything. It shows match strength as a visible sum of named factors. The officer sees exactly why the alert fired." |
| 2:30–3:00 | Officer clicks Link Cases. Picks PGRC as lead Bureau. Adds coordination note. Student's status updates live in the student tab. | "Both case histories stay separate. The link just coordinates. Watch the student's status update — no page refresh." |
| 3:00–3:30 | PGRC refers the case to Apex Institute College portal. College management assigns to a faculty member. The unassigned faculty account cannot open it. | "The college can only see cases referred to them. An unassigned faculty account gets access denied." |
| 3:30–4:15 | Switch to Senior Management tab. Dashboard tiles show updated counts. Open the Bureau-wise report. Export to CSV. | "Senior management sees a live view but cannot modify any case. Report scope respects their access." |
| 4:15–4:45 | Open the audit trail for the linked case. Show: who did what, when, the coordination note, the hash chain. | "Every action is append-only and hash-chained. The edit history is tamper-evident, not editable." |
| 4:45–5:00 | Return to student tab. Show the My Cases timeline in plain language. | "The student always knows what's happening and what to expect next — no jargon, just status." |

---

## 12. Cut List & Future Work

### Must Build (MVP — non-negotiable for judges)

- [ ] Four portals on one backend, role-based layouts
- [ ] Institution profiles with consolidated case history
- [ ] Full complaint lifecycle with all PS-required fields
- [ ] Both overlap alerts with explainable matching (factor breakdown UI)
- [ ] Link/dismiss workflow with reason capture
- [ ] Affiliation verification on synthetic rosters
- [ ] Correct permissions (RLS + application layer)
- [ ] Append-only hash-chained audit history
- [ ] Essential notifications (in-app + email)
- [ ] Labelled synthetic test set with measured matching precision/recall

### Build If Time Permits (Phase 5–6)

- [ ] OCR with correction UI and fallback
- [ ] Hindi interface + Hindi notification templates
- [ ] Marathi templates
- [ ] Downloadable reports (CSV/Excel/PDF)
- [ ] RAG policy assistant with citations
- [ ] Web Push for PWA
- [ ] Offline drafts for students
- [ ] Region-wise and institution-wise report pages
- [ ] Scheduled monthly report email to Bureau heads

### Explicitly Out of Scope (say this to judges)

- Real DigiLocker/APAAR integration (mock only, labelled)
- Custom model training (pre-trained embeddings only)
- Face or biometric verification
- SMS/WhatsApp notifications (DLT compliance needed)
- Public college rankings
- Microservices architecture
- Native mobile app (PWA covers the demo)
- Aadhaar-based verification (DPDP compliance)

---

## Appendix A — Six Independent Status Tracks per Case

```
Track 1: Verification
  Pending → Verified | Needs Review | Unable to Verify

Track 2: Lifecycle
  Submitted → Under Triage → Referred | Under Examination | Out of Scope
  Referred → Awaiting Response → Under Examination → Decision Recorded → Closed

Track 3: Coordination
  No Overlap → Possible Overlap → Linked | Dismissed

Track 4: Deadline
  On Track → Nearing → Overdue → Paused (with reason)

Track 5: Appeal
  Not Applicable → Eligible → Submitted → Under Review → Decided

Track 6: Urgency / Triage
  Untriaged → Triaged | Urgent (safety/serious misconduct) | Out of Scope (with reason + redirect)
```

These tracks are **independent**. "Verified" does not mean "accepted". "Overdue" does not mean "rejected". The UI always shows all six tracks clearly.

---

## Appendix B — Precision/Recall Measurement Plan

Build a labelled synthetic test set of 150+ complaint pairs:

| Category | Count | Description |
|---|---|---|
| True overlaps (same issue, same institution) | 30 | Should trigger Alert 2 |
| Cross-Bureau, different issues | 30 | Should trigger Alert 1 only, NOT Alert 2 |
| Different institutions, similar wording | 20 | Should NOT trigger either alert |
| Same institution, Hindi vs English versions | 15 | Should trigger Alert 2 |
| Spelling variations in institution name | 15 | Institution match should succeed; then alert logic applies |
| Hard negatives (same category, very different issue) | 20 | Should NOT trigger Alert 2 |
| Incomplete records (missing fields) | 20 | Should degrade gracefully |

Measure: precision, recall, F1 at multiple thresholds. Compare against rules-only baseline. Report in demo. Choose threshold by the cost asymmetry: a missed overlap (Alert 2 missed) costs duplicated officer work; a false alert costs officer review time.

---

*Document version 1.0 · October 2026 · NyayaSetu / CaseBridge AI · SIH PS 26264*
