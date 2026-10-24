# CaseBridge AI — SIH 2026 blueprint (PS 26264)

Oct 23, 2026 · @Krishna

## Vision and USP

**Pitch:** CaseBridge AI gives AICTE one institution profile that holds every complaint, action and alert across Bureaus/Cells, so RB, PGRC and the Regional Offices see each other's work before it overlaps. Cases stay separate, each with its own history, decision-maker and appeal route.

The official problem (PS 26264) is internal: the same institution gets handled by different Bureaus/Cells with no shared view. We solve that core first. The student, faculty and college portals are a *feeder layer*, not a separate product: they exist to give AICTE cleaner, verified, structured inflow.

**Four USPs, in the order to say them to judges:**

1. **Two separate alerts.** Coordination alert: an institution has open cases in 2+ Bureaus/Cells → "Potential Overlapping Cases – Coordination Required" (exactly the PS wording). Semantic level: two differently worded complaints about the same issue raise a separate Potential Related Cases alert.
2. **Explainable, human-confirmed links.** Every alert shows its reasons (same institution ID, category, similarity, dates). An officer links or dismisses; AI never merges or decides.
3. **Verified-affiliation intake.** Complainants are verified as current student, alumnus or staff against college rosters, with a manual path, and verification never lowers the priority of a safety or serious-misconduct allegation. Verification is kept separate from complaint credibility.
4. **Tamper-evident and offline-safe.** Offline drafts for students, and an append-only, hash-chained action history, so any rewrite of a case is detectable.

**What we do not claim:** we are not an official AICTE system, we use synthetic data, and our deadlines are configurable defaults, not AICTE rules.

## What real grievance portals do, and what we borrow

| Portal / rule | Notable features (from sources) | What we adopt |
| --- | --- | --- |
| [AICTE PGRC](https://aicte.gov.in/node/422) | Handles grievances of students, faculty and stakeholders of approved institutions, CPGRAMS-forwarded grievances, and ragging complaints | These three intake channels become source types on every case |
| [AICTE 2017 directive](https://www.medianama.com/2017/02/223-aicte-student-grievance-portal/) | Every institution runs its own online portal and sends AICTE a monthly status report (received, disposed, pending); portal performance counts at approval renewal | Institution-level monthly report auto-generated; institution responsiveness score feeds the AICTE view |
| [UGC 2023 regulations](https://loretocollege.edu.in/pages/redress-of-grievances-of-students) | Online portal at the college; complaint referred to the Student Grievance Redressal Committee (SGRC) within 15 days; hearing date set; unresolved cases go to an Ombudsperson | College-first routing, hearing scheduler, Ombudsperson appeal step |
| [UGC e-Samadhaan](https://sju.edu.in/uploads/cmsmenu/UGC%20E-Samadhaan%20Website%20Note_20240725025213.pdf) | Escalation to the regulator only after exhausting institutional remedies, with evidence | "Remedies exhausted" checkbox plus proof on escalation |
| [CPGRAMS](https://cga.gov.in/Page/CPGRAMS.aspx) | Unique registration ID, status tracking, appeal if feedback is "Poor", mobile app, 22 scheduled languages, auto-routing, postal complaints digitised, 21-day target, Nodal Appellate Authority for appeals, feedback call centre, AI voice chatbot built on Bhashini | Tracking ID, feedback-then-appeal loop, auto-routing, multilingual and voice intake, offline/paper complaint entry by officers |

Sources: [PIB on CPGRAMS (Aug 2026)](https://static.pib.gov.in/WriteReadData/specificdocs/documents/2026/aug/doc2026821966201.pdf), [PIB CPGRAMS note](https://static.pib.gov.in/WriteReadData/specificdocs/documents/2024/dec/doc20241230478501.pdf).

**Gap we fill:** none of these shows an officer, in one place, that two Bureaus are already working on the same institution. That is the PS, and it is our centre of gravity.

**Matters CPGRAMS excludes** (RTI, sub judice, religious, service matters) are a useful template: our intake should have an "out of scope" classification with a reason and a redirect, not a silent rejection.

## The portals: who sees what, and what they can do

One Next.js app, one backend, role-based layouts. The AICTE portal is the product's heart; the other three feed it.

### Portal 1 — Student / Alumnus (mobile-first PWA)

- **Onboarding:** register, verify email and phone OTP, pick institution, choose affiliation type (current student, alumnus), upload proof (optional, assists review).
- **Complaint wizard:** category picker with plain-language help, description in English/Hindi/Marathi or by voice, evidence upload (images, PDF), "is this urgent or safety-related" flag, confidentiality choice, preview, submit.
- **Duplicate check before submit:** "You already have a similar open complaint" with a link to follow up instead.
- **My cases:** tracking ID, plain-language status timeline, next expected date, requests for clarification, message thread with the case officer.
- **After closure:** rate the outcome; feedback is collected separately; appeal eligibility comes from the configured routing rules (recorded decision, applicable window, applicable route), not from the rating.
- **Privacy centre:** what is stored, consent log, request correction/erasure of verification documents.
- **Drafts offline:** write the complaint with no network; it syncs when back online.

### Portal 2 — Faculty / Committee member

- **Assigned-cases inbox** only; nothing else at the college is visible.
- **Conflict-of-interest declaration** on assignment; recuse with a reason, triggers reassignment.
- **Respond:** factual response form, evidence upload, internal notes, hearing minutes.
- **Hearing scheduler:** propose dates; student and institution are notified.
- **Workload view:** my open tasks and deadlines.

### Portal 3 — College management (Principal / Grievance Officer)

- **Institution profile:** AICTE permanent ID, committee roster (SGRC members, Ombudsperson contact), effective dates for every change.
- **Referred cases:** assign to a committee member, set internal deadline, submit the official response and action-taken report.
- **Student roster upload (CSV):** feeds affiliation verification; versioned and access-logged.
- **Compliance view:** monthly received/disposed/pending report (auto-generated, mirrors the 2017 AICTE directive), pending ageing.
- **Hard limit:** cases involving the Principal or management are *not* visible here; they are routed to an independent path.

### Portal 4 — AICTE (sub-roles, because the PS names several user groups)

| Sub-role | Home screen and key powers |
| --- | --- |
| PGRC triage officer | Intake queue: verify, categorise, route to college or Bureau; mark out of scope |
| Regulation Bureau officer | Cases needing regulatory action; link to PGRC cases; record inspection/show-cause steps |
| Other Bureau/Cell officer | Sees only cases routed to them; can request transfer |
| Regional Office officer | Cases for institutions in their region; **offline field notes (stretch goal)** for visits and evidence capture |
| Bureau head / Adviser | Workload, ageing, reassign, approve transfers |
| Competent Authority / senior management | Read-only live dashboard, institution risk view, scheduled reports |
| Ombudsperson | Appeal queue only |
| Auditor / system admin | Audit log, role changes, configuration (SLA rules, categories) with a reason on every change |

**AICTE dashboard (PS requirements mapped):** KPI tiles (total, pending, under process, disposed, transferred, beyond-timeline), institution profile page with consolidated case history, case table with every field the PS lists (case ID, receipt date, category, status, assigned Bureau/Cell, officer, last action, next action, last-action date, expected disposal date), filters on all eight search keys, overlap-alert centre, link/dismiss workflow, and Bureau-wise workload bars.

## How the portals affect each other

All four portals read and write the same case record. Nothing is copied between them; each action is an event, and each portal shows the slice its role may see.

| Event (who does it) | Student | Faculty / committee | College management | AICTE |
| --- | --- | --- | --- | --- |
| Student submits complaint | Gets case ID, status "Submitted" | Nothing | Nothing until referred | Lands in PGRC triage queue; duplicate and overlap check runs |
| PGRC refers to college | Status "Referred to institution", 15-day target shown | Notified only if assigned | Grievance officer sees it; assigns a member | Case stays visible; clock starts |
| Member recuses (conflict of interest) | Nothing | Case leaves their inbox | Must reassign; reason logged | Visible in audit trail |
| College submits response | Sees response summary, can answer or accept | Response attributed to them | Action-taken report attached | Officer reviews; can return for clarification |
| Overlap detected (RB and PGRC on same institution) | Not told unless it changes their case | Not shown | Shown only if institution-level action needed | Alert to both Bureaus; lead Bureau chosen; cases linked, histories stay separate |
| Deadline nears or passes | Reminder, then "delayed" notice | Task reminder | Reminder to coordinator | Escalation to Bureau head; shows in beyond-timeline tile |
| Decision recorded | Decision notice and rating prompt | Notified if involved | Notified | Case closes; disposal-rate stats update |
| Student rates "Poor" and appeals | Appeal tracked, if the configured rule allows one | Only if the process needs them | Informed if permitted | Goes to the Ombudsperson or appellate queue only if the configured appeal rule is met |
| Roster uploaded or changed | Re-verification may be asked | Nothing | Roster version logged | Auditor sees who changed what |

**Why this wins:** it shows judges the portals are views on one system. Change a case in one portal in the demo and the others update live.

## Authentication and fake-complaint defence

This is your most likely judge question, so the answer must be layered and honest: **no technology proves a complaint is true. We verify who is complaining and their link to the college, then route doubt to a human.**

### Login for each role

| Role | Login | Extra control |
| --- | --- | --- |
| Student / alumnus | Email + phone OTP (passwordless link or OTP) | Device sessions list, new-login alert |
| Faculty | Institutional email OTP | Linked to college roster entry |
| College management | Email OTP + authenticator app (TOTP) | Role granted only by AICTE-verified onboarding |
| AICTE officers | Official email + TOTP; production would use NIC/government SSO | Role, Bureau, region and purpose on every session |

### Affiliation verification (separate from the complaint)

1. **Contact proof:** OTP shows control of the email/phone only.
2. **Roster match:** the college uploads its student list. The student enters enrollment number and programme; the system matches against the roster.
3. **Document assist:** ID card or fee receipt is read with OCR and shown back to the student to correct. OCR output is a reading aid, never proof of authenticity.
4. **Outcome:** *Verified*, *Needs review* or *Unable to verify*. Needs-review items go to an **AICTE verification queue**, not only to the accused college, so a college cannot veto a complaint by denying enrollment.
5. **Alumni:** verified against historical roster or degree record; otherwise manual review. No current-year ID is required.
6. **Optional future step:** APAAR/ABC ID via DigiLocker. APAAR is a 12-digit student ID linked to DigiLocker and the Academic Bank of Credits ([PIB, Jul 2026](https://static.pib.gov.in/WriteReadData/specificdocs/documents/2026/jul/doc202675912501.pdf)). Production use needs partner onboarding, so we show it as a labelled mock.

### What if someone impersonates a student?

They must pass the OTP and match a roster entry that is not already claimed. One roster entry binds to one account; a second claim raises a *claim conflict* for manual review. Without a roster match they can still file, but the case is marked **unverified**, is held for an AICTE triage officer and is not auto-referred to the college until reviewed. Verification, triage and urgency are separate fields: a missing roster record never lowers the priority of a safety or serious-misconduct allegation, and an affiliation dispute is never treated as evidence that the complaint is false.

### Abuse and false-complaint controls

- Rate limits and CAPTCHA on registration and submission.
- Duplicate-attachment hashing and repeat-text detection; many complaints from one account are shown to a reviewer, not auto-blocked.
- Coordinated-looking bursts (many new accounts, same wording, same hour) raise a reviewer flag.
- A false statement is *recorded as evidence* for the authorised process; the system never penalises anyone itself.
- **Anonymity:** AICTE's approval guidelines restrict anonymous or pseudonymous complaints in the regulatory process, so we offer *confidential* handling (identity hidden from the college, visible to authorised AICTE officers) rather than promising anonymity.

### Privacy and law

The DPDP Rules 2025 were notified in November 2025 and come into force in stages: the last, substantive duties (notice, consent, security safeguards, breach reporting) begin 14 May 2027 ([AMSS summary](https://www.amsshardul.com/insight/enforcement-of-the-dpdp-act-and-notification-of-the-dpdp-rules/)). We design for them now: collect no Aadhaar number or biometrics, delete verification documents once verified (with notice), keep purpose-limited retention, and plan for 72-hour breach notification ([EY](https://www.ey.com/en_in/insights/cybersecurity/transforming-data-privacy-digital-personal-data-protection-rules-2025)). Most complainants are adults; if a minor is involved, the Rules require verifiable parental consent, with certain educational-institution exemptions, so we flag such cases for legal review rather than assume.

## Case lifecycle, overlap detection and timelines

### Six separate status tracks

Keep these independent so "identity verified" is never confused with "complaint accepted".

| Track | Values |
| --- | --- |
| Verification | Pending, verified, needs review, unable to verify |
| Lifecycle | Submitted, under triage, referred, under examination, awaiting response, decision recorded, closed |
| Coordination | No overlap, possible overlap, linked, dismissed |
| Deadline | On track, nearing, overdue, paused (with reason) |
| Appeal | Not applicable, eligible, submitted, under review, decided |
| Triage and urgency | Untriaged, triaged, urgent (safety or serious misconduct), out of scope with reason |

### Overlap detection: two separate alerts

1. **Alert 1, Cross-Bureau Coordination Required (deterministic, instant).** If an institution has open cases in two or more Bureaus/Cells, raise *Potential Overlapping Cases – Coordination Required*. It says only that several Bureaus are acting on one institution, not that the complaints are the same, so it never calls them duplicates.
2. **Alert 2, Potential Related Cases (assisted).** For cases of the same institution, score candidate pairs on: same category, text similarity (embedding cosine), date proximity, shared names or programmes, identical attachments, and whether different Bureaus hold them. Pairs above a threshold become *suggested links*.

Institution identity is the gate: AICTE permanent ID first, then fuzzy name match (typos, "Inst." vs "Institute") with human confirmation. Two similar complaints about *different* colleges are never flagged.

**Officer actions:** link, dismiss with reason, pick a lead Bureau, add a coordination note. Linked cases keep separate histories. Dismissals are remembered so the same pair does not re-alert.

**Example:** a pending faculty grievance in PGRC and an unrelated fee complaint in RB for the same college raise Alert 1 only. Two complaints about the same fee refund raise both alerts. Each alert shows its reasons and can be dismissed or linked by an authorised officer.

### Timelines

Deadlines come from a rules table an admin edits, each rule carrying its source, applicability (route, category), effective dates and approving authority. Suggested defaults to demo, **clearly labelled as configurable, not AICTE rules:** 15 days for the college to refer to its committee (UGC 2023 pattern), 21 days to resolve (CPGRAMS target), 30 days for an appeal (CPGRAMS appellate pattern). A job runs hourly, sets the deadline track, and fires reminders at 75% of time elapsed, at due date, and at escalation.

**Routing engine:** configurable paths for routine college grievances, complaints involving management, matters needing AICTE regulatory attention, and appeals. Timelines, routes and appeal eligibility must be confirmed against official AICTE procedures before they are presented as authoritative.

### Tamper evidence

Case events are append-only. Each event stores a hash of the previous one, so edits are detectable. This is a tamper-evident trail, not an immutable ledger: someone with database access could rewrite and re-hash it. So the app role gets insert-only rights, the superuser role is never used at runtime, and a daily hash of the chain head is written to a separate protected location (stretch goal). A "correction" is a new event that points to the old one.

## Notifications

**Rule one:** a notification never contains the complaint text, the allegation or attachments. It says *what happened* and links to the authenticated portal.

| Channel | Use | Notes |
| --- | --- | --- |
| In-app (live) | Everything | Realtime via the database; bell icon with unread count |
| Email | Confirmations, status changes, decisions, reminders | Queue with retries; one message per event (idempotency key) |
| Web Push | Deadline and action-needed alerts | Works in Chrome/Android PWA; on iPhone only after "Add to Home Screen" |
| SMS / WhatsApp | Future | Needs consent, a provider and, for SMS in India, sender/template registration; keep out of the MVP |

### How it is built

1. Every action writes an event row (the same append-only log).
2. A **policy table** maps event type → recipient roles → channel → template. Recipients are resolved from case participants *at send time*, so someone who lost access gets nothing.
3. A worker (pg-boss or BullMQ) sends, retries with backoff, and records delivery status.
4. Types: *transactional* (status changes), *operational* (tasks, deadlines, overdue), *security* (new login, role change, sensitive document opened).
5. Users set preferences per type and language (English/Hindi/Marathi templates).

**Sensitive case rule:** a complaint against the Principal never notifies the Principal or the management account; the policy marks it `restricted` and recipients come only from the AICTE or independent path.

## Mobile, offline mode and every-device responsiveness

### Do we need a mobile app?

**No native app for the hackathon.** Build one responsive web app as a Progressive Web App (PWA): installable, push-capable, offline-capable, one JavaScript codebase. A React Native app only makes sense later for deeper camera or background features.

| Portal | Primary device | Responsive priority |
| --- | --- | --- |
| Student | Phone | Mobile-first: single column, large touch targets, camera upload, voice input |
| Faculty | Phone and laptop | Task-list layout that works on both |
| College management | Laptop, tablet | Data tables with column priority; roster upload |
| AICTE officers | Desktop, large monitor | Dense dashboard; collapses to cards on tablet; Regional Officers use phone/tablet in the field |

**Responsive rules:** design at 360, 768, 1280 and 1920 px; tables become stacked cards below 768 px; charts resize and keep a text summary; test on low-end Android and slow 3G throttling; WCAG-style accessibility (keyboard use, contrast, screen-reader labels), because CPGRAMS itself lists accessibility for persons with disabilities among its next-generation features.

### Where offline mode has a real reason

1. **Student drafting:** colleges in low-connectivity areas. The complaint wizard saves to IndexedDB and syncs later; evidence uploads resume.
2. **Regional Office field visits (stretch goal):** an officer inspecting a campus records observations, photos and a checklist with no signal; actions queue and sync with a timestamp of when they were *captured*.
3. **Paper and walk-in complaints:** an officer keys in a paper complaint offline, mirroring CPGRAMS's practice of digitising postal complaints.

**How:** service worker caches the app shell only, never case data; IndexedDB holds a write queue; Background Sync replays it when online; on conflict the *server record wins* and the officer sees a merge screen. Offline never covers approvals, role changes or sensitive downloads; those need a live, authorised session.

**Security limit:** encrypting browser storage does not make it safe. Offline is limited to a student's own drafts and, as a stretch goal, minimal authorised field notes. No sensitive attachments and no case histories are cached. Sessions expire, a lost device can be revoked, unsynced items are cleared on logout, and the server revalidates everything on sync. Offline approvals and access-control changes are never authoritative.

## Reports and analytics

Every PS report is a saved query over the same case tables, with filters and export.

| PS report | What it shows | How it is produced |
| --- | --- | --- |
| Bureau/Cell-wise | Workload, open, disposed, average age | Materialised view refreshed every few minutes |
| Region-wise | Cases by Regional Office area | Group by institution region |
| Institution-wise history | Full case timeline per institution, with overlaps | Institution profile page, printable |
| Status-wise | Pending, under process, disposed, transferred, escalated | Live tiles |
| Ageing | Buckets 0–7, 8–15, 16–30, 30+ days (editable) | Bar chart plus drill-down list |
| Disposal rate | Disposed ÷ received per month | Trend line |
| Overlap / duplicate | Open alerts, linked pairs, dismissed, resolution time | Alert centre analytics |
| Monthly / quarterly performance | Per Bureau and per institution | Scheduled job generates PDF and Excel, stored and notified |

**Delivery:** on-screen with Recharts or ECharts; export to CSV, Excel (ExcelJS) and PDF (server-side render); a scheduled monthly pack emailed to Bureau heads. Reports respect the viewer's access scope, so a Regional Officer's export contains only their region.

**Also useful:** an institution *attention list* (many open cases, repeated overdue responses, multi-Bureau overlap). Show it as "needs coordination", not as a public ranking or a verdict on the college.

## AI: what we use and what we deliberately do not train

| Question | Answer |
| --- | --- |
| Do we need machine learning? | Yes, lightly. Pre-trained **multilingual text embeddings** for similarity. No custom deep model. |
| Do we need to train a model? | **No LLM training.** Optional later: a small category classifier (TF-IDF + logistic regression) trained on labelled *synthetic* complaints, only if it beats keyword rules in testing. |
| Do we need explainable AI? | **Yes, but as glass-box design**, not SHAP. The match score is a visible weighted sum of named factors, so the explanation is the model. |
| Do we need RAG? | **Yes, scoped:** a policy assistant for officers that answers from an approved document set with page citations, and says "not found" otherwise. |
| Should AI decide anything? | **Never.** It suggests, ranks and explains; a named officer decides. |

### 1. Overlap and duplicate matching

Candidate retrieval by institution, then score = weighted sum of: category match, embedding cosine, date proximity, shared entities (programme, person role, building), same attachment hash, different-Bureau flag. The UI shows each factor as a row with its contribution, plus the two complaints side by side with matching phrases highlighted. A similarity score is *not* a probability of duplication; label it "match strength".

### 2. RAG policy assistant

Corpus: AICTE Approval Process Handbook 2024–27, AICTE grievance notifications and Ombudsperson orders, UGC 2023 student grievance regulations, CPGRAMS guidelines. Chunk by section, store embeddings, retrieve top passages, generate an answer *only from them*, show the citation, abstain on weak retrieval. It answers "which committee handles this?" or "what documents are needed?", never "is this complaint valid?".

### 3. Multilingual and voice

English, Hindi and Marathi in the UI and templates. [Bhashini](https://bhashini.gitbook.io/bhashini-apis) offers translation and speech services for Indian languages, and CPGRAMS's chatbot uses it ([PIB](https://static.pib.gov.in/WriteReadData/specificdocs/documents/2026/aug/doc202689948801.pdf)); check access terms before relying on it, and keep the original text beside any translation.

### 4. OCR

Tesseract.js in the browser for ID/receipt field extraction, with user correction and confidence shown. It is a convenience for faster verification, never evidence of authenticity.

### Evaluation we can show

Build 150 or more labelled synthetic complaint pairs that include the hard cases: same institution but different issue, different institution with similar wording, related but not duplicate, spelling variations, Hindi and Marathi text, and incomplete records. Compare the matcher against a rules-only baseline and report precision, recall and example false positives. Choose the alert threshold by the cost of a wrong alert: a missed overlap costs duplicated work, a false alert costs officer time, so tune and show both.

## JavaScript tech stack, database and security

All JavaScript/TypeScript, one repo, one deployable app (a modular monolith).

| Layer | Choice | Reason |
| --- | --- | --- |
| Frontend | Next.js + TypeScript + Tailwind + shadcn/ui, PWA (service worker, manifest) | One codebase, role layouts, installable |
| Charts / tables | Recharts or ECharts, TanStack Table | Dense dashboards that collapse to cards |
| Backend | Next.js route handlers or Fastify, Zod validation | Typed, shared schemas with the frontend |
| Database | **PostgreSQL** (Supabase or Neon) | Relational integrity, joins for reports, row-level security |
| Fuzzy + semantic search | `pg_trgm` (name matching), `pgvector` (embeddings), full-text search | Matching inside the same database; no extra service |
| Auth | Supabase Auth or Auth.js, email/phone OTP, TOTP for officers | Fast to build, standard flows |
| Files | Private object storage with signed, expiring URLs | Evidence never public |
| Jobs | pg-boss (Postgres-backed) or BullMQ + Redis | Reminders, emails, embeddings, reports |
| Realtime | Database realtime channel or Server-Sent Events | Live dashboard and bell |
| Embeddings | Open multilingual model via transformers.js, or a hosted embeddings API | Hindi/Marathi support |
| OCR | Tesseract.js | Runs in browser, no document leaves the device until confirmed |
| Exports | ExcelJS, server-side PDF | Report packs |
| Testing | Vitest, Playwright, k6 | Role tests, e2e demo script, load test |

**Why PostgreSQL, not MongoDB:** cases, roles, institutions and events are strongly relational, and access rules need row-level security. Document stores make cross-Bureau reporting and permission checks harder.

**Domain modules:** complaint lifecycle, notification policy, authorisation and overlap scoring are backend modules that every portal calls; no portal carries its own copy of the rules. For example, one `submitComplaint` operation validates the request, records the case, appends an audit event and schedules only the permitted notifications.

### Core tables

`institutions`, `users`, `affiliations`, `role_assignments`, `complaints`, `participants`, `evidence`, `verification_attempts`, `case_events` (append-only, hash-chained), `case_links`, `overlap_alerts`, `deadline_rules`, `deadlines`, `notifications`, `notification_policies`, `audit_events`, `policy_chunks` (RAG), `report_runs`.

### Security checklist

- Authorise every request on the server; add Postgres row-level security as a second lock.
- Tenant isolation: institution ID comes from the session, never from the request body.
- Confidential cases restrict detail views, exports and notifications together.
- Log who opened a sensitive record and why; admin overrides need a reason.
- Encrypt at rest, TLS everywhere, signed upload URLs, malware scan on uploads, security headers, dependency scanning.
- Seed data is synthetic and labelled "DEMO" in the UI.

## Build plan, demo data and what to cut

### Priority order

The PS rewards the AICTE core first. Build in this order and stop adding when time runs out.

| Phase | Deliver | Done when |
| --- | --- | --- |
| 1. Foundation and access control | Schema, auth, roles, institution isolation, case visibility, audit events, synthetic seed | Another institution's cases cannot be read or changed through the UI or the API; tested |
| 2. AICTE dashboard and lifecycle | Institution profile, case table, the eight PS search keys, transitions, assignments, transfers, action history, deadline rules | An officer tracks a case from intake to a recorded decision |
| 3. Overlap detection and review | Coordination alert, related-case matching, explainable factors, link or dismiss with a reason | Seeded overlaps are found; false matches are dismissed with reasons |
| 4. Feeder portals | Student submission and tracking, affiliation review, faculty inbox, college response | One case flows through all portals with correct permissions |
| 5. Notifications, OCR, languages | Event-driven notifications with retries, OCR with correction and fallback, English and Hindi templates | Right recipients only; an OCR failure has a safe fallback |
| 6. Reports, RAG, hardening | Reports and exports, policy assistant with citations, accessibility and security tests, demo rehearsal | Scripted demo is repeatable; every integration is labelled real or simulated |

Do not start a phase until the previous one's "done when" passes.

### Scope tiers

- **Must build:** four portals on one backend, institution profiles, complaint lifecycle, both alerts with explainable matching, affiliation verification on synthetic rosters, correct permissions, audit history, essential notifications, a labelled test set with measured matching performance.
- **Build if stable:** OCR, English/Hindi/Marathi interface, institution relationship graph, deadline analytics and downloadable reports, RAG policy assistant.
- **Future work:** government identity and system integrations, secure field offline mode, advanced fraud-pattern analysis, speech in more languages, external anchoring of audit hashes.

**Freeze before writing code:** the MVP requirements, the database schema, the permission matrix and the case state-transition rules.

### Synthetic data (labelled DEMO)

About 300 institutions across regions and types, 10–20k student roster rows, 1–3k complaints, and 100+ hand-crafted overlap scenarios (same college in RB and PGRC; same issue worded differently; similar issue at two colleges; a transferred case; an overdue case; a sensitive case against management). Names, IDs and outcomes are fictional.

### Five-minute demo script

1. Student on a phone files a complaint; sees tracking ID.
2. PGRC officer sees it in triage with a verification badge.
3. RB already has a case on the same college; the *Coordination Required* alert appears with its reasons.
4. Officer links the cases and chooses a lead Bureau; the student's status updates live.
5. College portal receives the referral; an unassigned faculty account cannot open it.
6. Dashboard tiles and a Bureau-wise report update; open the audit trail.

### Cut list

Real DigiLocker/APAAR, custom model training, face or biometric checks, SMS/WhatsApp, public college rankings, microservices.

## Judge Q&A

| Question | Short answer |
| --- | --- |
| How do you know the student is real? | We verify contact, then match the claimed enrollment against a college-supplied roster, with OCR as an aid. Doubt goes to an AICTE-side review queue. We never claim a complaint is *true*, only that the complainant is *linked* to the college. |
| A stranger files a fake report. | They cannot match an unclaimed roster entry, so the case is marked unverified, held for AICTE triage, and not auto-forwarded to the college; urgent allegations are still reviewed first. Rate limits, duplicate detection and burst flags add friction. |
| Can the college suppress a genuine complaint? | No. Intake goes to AICTE triage first; verification disputes go to AICTE; complaints against management never reach management accounts; all events are hash-chained. |
| Why not just use CPGRAMS? | CPGRAMS routes public grievances across government. It does not give AICTE an institution-level view of what RB, PGRC and Regional Offices are each doing about the same college. |
| What is novel versus a dashboard? | The institution-level overlap rule, the explainable pair matcher, and the human link/dismiss workflow, plus verified intake that feeds it. |
| Is your AI explainable? | Match strength is a visible weighted sum of named factors with highlighted evidence. There is no black box to explain after the fact. |
| Did you train a model? | No, deliberately: no real labelled data exists and training adds risk. We use pre-trained embeddings and measure precision/recall on a labelled synthetic set against a rules baseline. |
| Why RAG? | Officers need correct, cited procedure fast. It retrieves only from official documents and abstains when unsure. It cannot decide a case. |
| What about privacy law? | DPDP Rules 2025 are phased, with substantive duties from 14 May 2027. We already minimise data, avoid Aadhaar and biometrics, delete verification documents after use, log access, and plan breach notification. |
| Can it scale to \~10,000 institutions? | Postgres with indexes on institution ID, status and Bureau; materialised views for reports; queues for heavy work; read replicas if needed. We load-test the seed set and report numbers. |
| What if the internet is bad? | PWA caches the app, drafts and field notes queue offline and sync later; approvals always need a live session. |
| Who can see what? | Role, institution, assignment, Bureau, region and confidentiality are all checked on the server and in the database. A faculty member sees only assigned cases. |
| Are deadlines real AICTE rules? | No. They are configurable defaults with a source field (UGC 2023, CPGRAMS patterns) that AICTE can overwrite. |
| How does it integrate with AICTE systems? | Behind adapter interfaces: CSV/API import of institution master data and existing cases, and later single sign-on. The prototype uses mocks, labelled as such. |
| What happens when two Bureaus disagree? | The alert forces a lead-Bureau decision with a note; both histories stay; escalation goes to the Bureau head. |
| How is this different from each college's own portal? | Colleges already run portals under AICTE directions; our college portal is the structured link into AICTE's view, with monthly reporting automated. |
| Is the audit trail immutable? | No, it is tamper-evident. Events are append-only and hash-chained, the app role cannot update or delete them, and corrections are new events. Anchoring chain hashes outside the database is the production step. |
| How do the two alerts differ? | Coordination Required means several Bureaus handle cases for one institution, whatever the issue. Potential Related Cases means two specific complaints look like the same issue. Each explains itself and can be dismissed or linked by an officer. |

### Caveats to say out loud

Regional Offices are listed as ten to twelve cities across sources, so confirm the current list before seeding. Official timelines and escalation rules must be validated against AICTE's own notifications before any real use.

### Sources

- [AICTE PGRC page](https://aicte.gov.in/node/422) · [AICTE bureaus](https://aicte.gov.in/bureaus) · [Regional Offices](<https://aicte.gov.in/sites/default/files/ROs%20Details%20(2).pdf>)
- [MediaNama on AICTE 2017 portal directive](https://www.medianama.com/2017/02/223-aicte-student-grievance-portal/) · [Deccan Herald](https://www.deccanherald.com/india/centre-wants-effective-grievance-redressal-1993194)
- [UGC 2023 procedure as published by a college](https://loretocollege.edu.in/pages/redress-of-grievances-of-students) · [AICTE Ombudsperson notification](https://www.mrec.ac.in/MREC_GRIEVANCE/Ombudsman.pdf)
- [CPGRAMS, CGA](https://cga.gov.in/Page/CPGRAMS.aspx) · [PIB, Aug 2026](https://static.pib.gov.in/WriteReadData/specificdocs/documents/2026/aug/doc2026821966201.pdf)
- [DPDP Rules timeline](https://www.amsshardul.com/insight/enforcement-of-the-dpdp-act-and-notification-of-the-dpdp-rules/) · [EY on DPDP Rules](https://www.ey.com/en_in/insights/cybersecurity/transforming-data-privacy-digital-personal-data-protection-rules-2025)
- [APAAR / ABC, PIB Jul 2026](https://static.pib.gov.in/WriteReadData/specificdocs/documents/2026/jul/doc202675912501.pdf)
