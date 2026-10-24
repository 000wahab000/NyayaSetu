# NyayaSetu database schema (Phase 0 proposal)

Status: **planning baseline derived from `sources/NyayaSetu_ProjectPlan.md`**. Review with the team before Phase 0 is declared complete. Additive changes are allowed after freeze; renaming or dropping a table/column is not. Use UUID primary keys unless stated otherwise. All timestamps are UTC `timestamptz`; foreign keys use `ON DELETE RESTRICT` except where soft deletion is specified.

## Conventions and invariants

- `institutions.status` and `users.is_active` implement soft disable; never delete institutional or user records referenced by cases/events.
- `complaints` is the current projection. `case_events` is the append-only, hash-chained history; corrections are new events. Do not cascade-update/delete events.
- Institution scope is derived from the authenticated session/affiliation, never trusted from request data.
- Confidentiality controls complaint details, evidence, exports, and notifications together. `involves_management=true` excludes the named institution's management from access and notifications.
- Keep verification, lifecycle, coordination, deadline, appeal, and urgency as independent tracks (see `state-machine.md`).
- Evidence limit: 10 MiB per file, at most 5 files per complaint. Store object keys, not public URLs.
- Apply the retention defaults below in the prototype; these are product defaults, not a claim about statutory retention obligations.

## Decisions to freeze for the MVP

### Complaint categories

Use exactly these top-level categories in the MVP: `financial`, `ragging`, `academic`, `infrastructure`, `other`. Keep `secondary_category` as optional free text (maximum 80 characters) so a taxonomy change does not require a breaking enum migration. Unknown input must map to `other` only with user confirmation, never silently.

### Lifecycle and track enums

- Lifecycle `complaints.status`: `submitted`, `under_triage`, `referred`, `awaiting_response`, `under_examination`, `decision_recorded`, `closed`, `out_of_scope`, `transferred`, `appeal_submitted`, `under_appeal_review`, `appeal_decided`.
- Verification: `pending`, `verified`, `needs_review`, `unable_to_verify`.
- Coordination: `no_overlap`, `possible_overlap`, `linked`, `dismissed`.
- Deadline: `on_track`, `nearing`, `overdue`, `paused`.
- Appeal: `not_applicable`, `eligible`, `submitted`, `under_review`, `decided`.
- Urgency/triage: `untriaged`, `triaged`, `urgent`, `out_of_scope`.

Store stable lowercase values; present human-readable labels in the UI. Transitions and appeal eligibility are defined in `state-machine.md`.

### Retention defaults (prototype)

| Data | Default retention |
|---|---|
| Complaint records and case events | Retain 5 years after closure, then anonymize complainant identity and free-text content while preserving non-identifying case metrics. Do not hard-delete the event chain. |
| Evidence attachments | Delete 1 year after case closure; record a tombstone event and retain non-content metadata/hash for the complaint retention period. |
| Verification documents and OCR source images | Delete within 30 days after verification decision; retain only decision, method, reviewer, timestamp, and corrected fields needed for affiliation. |
| Uploaded roster source files | Retain 90 days after a newer roster version becomes active; delete old source file, retain roster version metadata and rows only while required for verification. |
| User accounts | While active or linked to an open case; on approved account closure, remove direct contact identifiers within 30 days if no open case requires them. Keep pseudonymous references in retained case history. |
| Security/audit access logs | 1 year; case action events follow the complaint retention period. |
| Backups | 30-day rolling retention; expiry must remove data from backups on normal rotation. |
| Synthetic demo records | No personal data; keep until reset or project teardown. |

These defaults require legal/policy review before real complaints are accepted. Implement with a daily scheduled cleanup job and an auditable deletion/anonymization record; this uses application/database features and does not require a paid retention service. Never promise that a provider's free tier is permanent or compliant.

## Tables

| Table | Columns and constraints |
|---|---|
| `institutions` | `id uuid PK`; `aicte_permanent_id text UNIQUE NOT NULL`; `name text NOT NULL`; `region text NOT NULL`; `address text`; `type text NOT NULL`; `status text NOT NULL` (`active`,`inactive`); `created_at timestamptz NOT NULL`; `updated_at timestamptz NOT NULL`; `deleted_at timestamptz NULL` (soft delete only). |
| `users` | `id uuid PK`; `email text UNIQUE`; `phone text UNIQUE`; `display_name text NOT NULL`; `is_active boolean NOT NULL DEFAULT true`; `created_at timestamptz NOT NULL`; `updated_at timestamptz NOT NULL`. Role is in `role_assignments`, not a single mutable user field. |
| `role_assignments` | `id uuid PK`; `user_id uuid FK users`; `role text NOT NULL`; `bureau text NULL`; `institution_id uuid FK institutions NULL`; `region text NULL`; `granted_by uuid FK users`; `granted_at timestamptz NOT NULL`; `revoked_at timestamptz NULL`; `reason text NOT NULL`; check role-specific scope (institution roles require institution; Bureau roles require bureau; regional roles require region). |
| `affiliations` | `id uuid PK`; `user_id uuid FK users`; `institution_id uuid FK institutions`; `type text NOT NULL` (`current_student`,`alumnus`,`faculty`); `enrollment_no text NULL`; `programme text NULL`; `year text NULL`; `status text NOT NULL` (`pending`,`verified`,`needs_review`,`unable_to_verify`); `claimed_at timestamptz NOT NULL`; `reviewed_at timestamptz NULL`; unique active claim per user/institution/type. |
| `verification_attempts` | `id uuid PK`; `affiliation_id uuid FK affiliations`; `method text NOT NULL` (`roster`,`document`,`manual`); `ocr_raw jsonb NULL`; `user_corrected jsonb NULL`; `ocr_confidence real NULL`; `outcome text NOT NULL`; `reviewed_by uuid FK users NULL`; `reviewed_at timestamptz NULL`; `created_at timestamptz NOT NULL`. Do not retain verification source documents beyond the approved retention policy. |
| `roster_versions` | `id uuid PK`; `institution_id uuid FK institutions`; `uploaded_by uuid FK users`; `uploaded_at timestamptz NOT NULL`; `row_count integer NOT NULL CHECK >=0`; `file_path text NOT NULL`; `is_active boolean NOT NULL`; `version_label text NOT NULL`; one active version per institution. |
| `roster_rows` | `id uuid PK`; `version_id uuid FK roster_versions`; `enrollment_no text NOT NULL`; `name text NOT NULL`; `programme text`; `year text`; `is_claimed boolean NOT NULL DEFAULT false`; unique `(version_id,enrollment_no)`. |
| `complaints` | `id uuid PK`; `case_id text UNIQUE NOT NULL` (human-readable); `institution_id uuid FK institutions`; `submitted_by uuid FK users`; `submitted_at timestamptz NOT NULL`; `receipt_date date NOT NULL`; `category text NOT NULL` (`financial`,`ragging`,`academic`,`infrastructure`,`other`); `secondary_category text NULL`; `description_text text NOT NULL`; `description_language text NOT NULL`; `description_embedding vector(768) NULL`; `status text NOT NULL` (lifecycle enum below); `verification_status text NOT NULL`; `coordination_status text NOT NULL`; `deadline_status text NOT NULL`; `appeal_status text NOT NULL`; `urgency_status text NOT NULL`; `assigned_bureau text NULL`; `assigned_officer uuid FK users NULL`; `last_action_at timestamptz NULL`; `next_action text NULL`; `next_action_at timestamptz NULL`; `expected_disposal_at timestamptz NULL`; `is_confidential boolean NOT NULL DEFAULT false`; `involves_management boolean NOT NULL DEFAULT false`; `is_demo boolean NOT NULL DEFAULT false`; `version integer NOT NULL DEFAULT 1 CHECK >0`; `created_at timestamptz NOT NULL`; `updated_at timestamptz NOT NULL`. |
| `participants` | `id uuid PK`; `complaint_id uuid FK complaints`; `user_id uuid FK users`; `role text NOT NULL` (`complainant`,`officer`,`faculty`,`college_officer`,`auditor`); `added_at timestamptz NOT NULL`; `removed_at timestamptz NULL`; `access_scope text NOT NULL` (`full`,`response_only`,`redacted_summary`); unique active `(complaint_id,user_id)`. |
| `evidence` | `id uuid PK`; `complaint_id uuid FK complaints`; `uploaded_by uuid FK users`; `file_path text NOT NULL`; `mime_type text NOT NULL`; `size_bytes bigint NOT NULL CHECK 0..10485760`; `hash_sha256 text NOT NULL`; `malware_scanned_at timestamptz NULL`; `malware_clean boolean NULL`; `uploaded_at timestamptz NOT NULL`; `is_ocr_source boolean NOT NULL DEFAULT false`. Max five rows per complaint, enforced transactionally. |
| `case_events` | `id uuid PK`; `complaint_id uuid FK complaints`; `event_type text NOT NULL`; `actor_id uuid FK users NULL` (system events permitted); `actor_role text NOT NULL`; `bureau text NULL`; `old_state jsonb NULL`; `new_state jsonb NULL`; `remarks text NULL`; `document_ids uuid[] NOT NULL DEFAULT '{}'`; `event_at timestamptz NOT NULL`; `prev_event_hash text NULL`; `event_hash text NOT NULL`; unique `(complaint_id,event_at,id)`. Append-only; database role has INSERT/SELECT only. |
| `overlap_alerts` | `id uuid PK`; `institution_id uuid FK institutions`; `alert_type text NOT NULL` (`coordination`,`related`); `status text NOT NULL` (`open`,`linked`,`dismissed`,`reopened`); `complaint_ids uuid[] NOT NULL`; `triggered_at timestamptz NOT NULL`; `reviewed_by uuid FK users NULL`; `reviewed_at timestamptz NULL`; `review_reason text NULL`; `match_factors jsonb NOT NULL DEFAULT '{}'`; `reopened_by uuid FK users NULL`; `reopened_at timestamptz NULL`. |
| `case_links` | `id uuid PK`; `alert_id uuid FK overlap_alerts`; `complaint_a_id uuid FK complaints`; `complaint_b_id uuid FK complaints`; `lead_bureau text NOT NULL`; `link_reason text NOT NULL`; `linked_by uuid FK users`; `linked_at timestamptz NOT NULL`; enforce distinct complaint IDs and canonical unique pair. |
| `dismissed_pairs` | `id uuid PK`; `complaint_a_id uuid FK complaints`; `complaint_b_id uuid FK complaints`; `dismissed_by uuid FK users`; `dismissed_at timestamptz NOT NULL`; `reason text NOT NULL`; `can_reopen boolean NOT NULL DEFAULT true`; canonical unique pair. |
| `deadline_rules` | `id uuid PK`; `name text NOT NULL`; `route text NOT NULL`; `category text NULL`; `days_to_deadline integer NOT NULL CHECK >0`; `source_citation text NOT NULL`; `effective_from date NOT NULL`; `approved_by uuid FK users`; `is_active boolean NOT NULL DEFAULT true`; `created_at timestamptz NOT NULL`. Defaults are configurable and must not be presented as official AICTE rules without validation. |
| `deadlines` | `id uuid PK`; `complaint_id uuid FK complaints`; `rule_id uuid FK deadline_rules`; `due_at timestamptz NOT NULL`; `status text NOT NULL` (`on_track`,`nearing`,`overdue`,`paused`); `paused_reason text NULL`; `last_checked_at timestamptz NULL`; unique active deadline per complaint/rule. |
| `notification_policies` | `id uuid PK`; `event_type text NOT NULL`; `recipient_role text NOT NULL`; `channel text NOT NULL` (`in_app`,`email`); `template_key text NOT NULL`; `is_active boolean NOT NULL DEFAULT true`; `restricted_case_rule text NOT NULL`. No allegation or attachment content in notifications. |
| `notifications` | `id uuid PK`; `user_id uuid FK users`; `complaint_id uuid FK complaints NULL`; `event_type text NOT NULL`; `channel text NOT NULL`; `status text NOT NULL`; `idempotency_key text UNIQUE NOT NULL`; `sent_at timestamptz NULL`; `read_at timestamptz NULL`; `created_at timestamptz NOT NULL`. |
| `policy_chunks` | `id uuid PK`; `document_name text NOT NULL`; `section text NOT NULL`; `page text NULL`; `content_text text NOT NULL`; `embedding vector(768) NOT NULL`; `indexed_at timestamptz NOT NULL`. Phase 0 schema reservation; feature is out of MVP. |
| `report_runs` | `id uuid PK`; `report_type text NOT NULL`; `requested_by uuid FK users`; `params jsonb NOT NULL`; `status text NOT NULL`; `file_path text NULL`; `generated_at timestamptz NULL`; `created_at timestamptz NOT NULL`. Reports are out of MVP. |
| `audit_events` | `id uuid PK`; `actor_id uuid FK users NULL`; `action text NOT NULL`; `resource_type text NOT NULL`; `resource_id uuid NULL`; `old_value jsonb NULL`; `new_value jsonb NULL`; `ip_address inet NULL`; `session_id uuid NULL`; `reason text NULL`; `event_at timestamptz NOT NULL`. Append-only. |

## Indexes and resolved planning decisions

Index complaints by `(institution_id,status)`, `(assigned_bureau,status)`, `receipt_date`, `expected_disposal_at`, and trigram/full-text search fields; index event history by `(complaint_id,event_at)`; index role assignments by active `user_id,role`; deadlines by `(status,due_at)`; alerts by `(institution_id,status,alert_type)`. Add vector and trigram indexes when selecting concrete database extensions.

Planning choice: retain `complaint_ids uuid[]` for the small MVP alert pair/group payload to reduce implementation work; if multi-case alert operations become common, add an `overlap_alert_cases` join table additively. Role names should use the role identifiers in `permissions.md`. Apply the retention defaults above and validate them before any live deployment. These decisions are now selected for the MVP baseline; the team can approve the freeze without choosing these values again.
