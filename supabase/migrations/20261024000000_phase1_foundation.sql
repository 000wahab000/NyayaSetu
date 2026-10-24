-- NyayaSetu Phase 1 foundation. Run only after reviewing docs/schema.md and linking the intended Supabase project.
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists vector with schema extensions;

create type public.app_role as enum ('student','faculty','college_management','pgrc_triage_officer','bureau_officer','regional_officer','bureau_head','competent_authority','ombudsperson','auditor','system_admin');
create type public.case_category as enum ('financial','ragging','academic','infrastructure','other');
create type public.lifecycle_status as enum ('submitted','under_triage','referred','awaiting_response','under_examination','decision_recorded','closed','out_of_scope','transferred','appeal_submitted','under_appeal_review','appeal_decided');
create type public.verification_status as enum ('pending','verified','needs_review','unable_to_verify');
create type public.coordination_status as enum ('no_overlap','possible_overlap','linked','dismissed');
create type public.deadline_status as enum ('on_track','nearing','overdue','paused');
create type public.appeal_status as enum ('not_applicable','eligible','submitted','under_review','decided');
create type public.urgency_status as enum ('untriaged','triaged','urgent','out_of_scope');

create table public.institutions (
  id uuid primary key default gen_random_uuid(), aicte_permanent_id text unique not null,
  name text not null, region text not null, address text, type text not null,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table public.users (
  id uuid primary key references auth.users(id) on delete restrict,
  email text unique, phone text unique, display_name text not null,
  is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.role_assignments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete restrict,
  role public.app_role not null, bureau text, institution_id uuid references public.institutions(id) on delete restrict,
  region text, granted_by uuid references public.users(id) on delete restrict, granted_at timestamptz not null default now(),
  revoked_at timestamptz, reason text not null,
  check ((role in ('student','faculty','college_management') and institution_id is not null and bureau is null and region is null)
      or (role in ('bureau_officer','pgrc_triage_officer','bureau_head') and bureau is not null and institution_id is null and region is null)
      or (role = 'regional_officer' and region is not null and institution_id is null)
      or (role in ('competent_authority','ombudsperson','auditor','system_admin') and institution_id is null)),
  check (revoked_at is null or revoked_at >= granted_at)
);
create unique index one_active_role_assignment on public.role_assignments(user_id) where revoked_at is null;

create table public.affiliations (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete restrict,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  type text not null check (type in ('current_student','alumnus','faculty')), enrollment_no text, programme text, year text,
  status public.verification_status not null default 'pending', claimed_at timestamptz not null default now(), reviewed_at timestamptz
);
create unique index one_active_affiliation_claim on public.affiliations(user_id,institution_id,type) where status <> 'unable_to_verify';
create table public.roster_versions (
  id uuid primary key default gen_random_uuid(), institution_id uuid not null references public.institutions(id) on delete restrict,
  uploaded_by uuid not null references public.users(id) on delete restrict, uploaded_at timestamptz not null default now(),
  row_count integer not null default 0 check(row_count >= 0), file_path text not null, is_active boolean not null default false, version_label text not null
);
create unique index one_active_roster_version on public.roster_versions(institution_id) where is_active;
create table public.roster_rows (
  id uuid primary key default gen_random_uuid(), version_id uuid not null references public.roster_versions(id) on delete restrict,
  enrollment_no text not null, name text not null, programme text, year text, is_claimed boolean not null default false,
  unique(version_id,enrollment_no)
);
create table public.verification_attempts (
  id uuid primary key default gen_random_uuid(), affiliation_id uuid not null references public.affiliations(id) on delete restrict,
  method text not null check(method in ('roster','document','manual')), ocr_raw jsonb, user_corrected jsonb,
  ocr_confidence real check(ocr_confidence between 0 and 1), outcome public.verification_status not null,
  reviewed_by uuid references public.users(id) on delete restrict, reviewed_at timestamptz, created_at timestamptz not null default now()
);

create table public.complaints (
  id uuid primary key default gen_random_uuid(), case_id text unique not null default '',
  institution_id uuid not null references public.institutions(id) on delete restrict,
  submitted_by uuid not null references public.users(id) on delete restrict,
  submitted_at timestamptz not null default now(), receipt_date date not null default current_date,
  category public.case_category not null, secondary_category text check(length(secondary_category) <= 80),
  description_text text not null check(length(description_text) between 50 and 5000), description_language text not null default 'en',
  description_embedding extensions.vector(768), status public.lifecycle_status not null default 'submitted',
  verification_status public.verification_status not null default 'pending', coordination_status public.coordination_status not null default 'no_overlap',
  deadline_status public.deadline_status not null default 'on_track', appeal_status public.appeal_status not null default 'not_applicable',
  urgency_status public.urgency_status not null default 'untriaged', assigned_bureau text, assigned_officer uuid references public.users(id) on delete restrict,
  last_action_at timestamptz, next_action text, next_action_at timestamptz, expected_disposal_at timestamptz,
  is_confidential boolean not null default false, involves_management boolean not null default false,
  is_demo boolean not null default false, version integer not null default 1 check(version > 0),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index complaints_institution_status_idx on public.complaints(institution_id,status);
create index complaints_bureau_status_idx on public.complaints(assigned_bureau,status);
create index complaints_disposal_idx on public.complaints(expected_disposal_at);
create index complaints_case_id_trgm_idx on public.complaints using gin(case_id extensions.gin_trgm_ops);
create table public.participants (
  id uuid primary key default gen_random_uuid(), complaint_id uuid not null references public.complaints(id) on delete restrict,
  user_id uuid not null references public.users(id) on delete restrict,
  role text not null check(role in ('complainant','officer','faculty','college_officer','auditor')),
  added_at timestamptz not null default now(), removed_at timestamptz,
  access_scope text not null default 'full' check(access_scope in ('full','response_only','redacted_summary'))
);
create or replace function public.assign_case_id()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if new.case_id = '' then new.case_id := 'NS-' || to_char(current_date,'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)); end if;
  return new;
end;
$$;
create trigger complaints_assign_case_id before insert on public.complaints for each row execute function public.assign_case_id();
create unique index one_active_case_participant on public.participants(complaint_id,user_id) where removed_at is null;
create table public.evidence (
  id uuid primary key default gen_random_uuid(), complaint_id uuid not null references public.complaints(id) on delete restrict,
  uploaded_by uuid not null references public.users(id) on delete restrict, file_path text not null, mime_type text not null,
  size_bytes bigint not null check(size_bytes between 0 and 10485760), hash_sha256 text not null,
  malware_scanned_at timestamptz, malware_clean boolean, uploaded_at timestamptz not null default now(), is_ocr_source boolean not null default false
);
create table public.case_events (
  id uuid primary key default gen_random_uuid(), complaint_id uuid not null references public.complaints(id) on delete restrict,
  event_type text not null, actor_id uuid references public.users(id) on delete restrict, actor_role text not null,
  bureau text, old_state jsonb, new_state jsonb, remarks text, document_ids uuid[] not null default '{}',
  visibility text not null default 'internal' check(visibility in ('internal','complainant','college','public')),
  event_at timestamptz not null default now(), prev_event_hash text, event_hash text not null
);
create index case_events_timeline_idx on public.case_events(complaint_id,event_at,id);
create table public.overlap_alerts (
  id uuid primary key default gen_random_uuid(), institution_id uuid not null references public.institutions(id) on delete restrict,
  alert_type text not null check(alert_type in ('coordination','related')), status text not null check(status in ('open','linked','dismissed','reopened')),
  complaint_ids uuid[] not null, triggered_at timestamptz not null default now(), reviewed_by uuid references public.users(id) on delete restrict,
  reviewed_at timestamptz, review_reason text, match_factors jsonb not null default '{}', reopened_by uuid references public.users(id) on delete restrict, reopened_at timestamptz
);
create table public.case_links (
  id uuid primary key default gen_random_uuid(), alert_id uuid not null references public.overlap_alerts(id) on delete restrict,
  complaint_a_id uuid not null references public.complaints(id) on delete restrict, complaint_b_id uuid not null references public.complaints(id) on delete restrict,
  lead_bureau text not null, link_reason text not null, linked_by uuid not null references public.users(id) on delete restrict,
  linked_at timestamptz not null default now(), check(complaint_a_id < complaint_b_id), unique(complaint_a_id,complaint_b_id)
);
create table public.dismissed_pairs (
  id uuid primary key default gen_random_uuid(), complaint_a_id uuid not null references public.complaints(id) on delete restrict,
  complaint_b_id uuid not null references public.complaints(id) on delete restrict, dismissed_by uuid not null references public.users(id) on delete restrict,
  dismissed_at timestamptz not null default now(), reason text not null, can_reopen boolean not null default true,
  check(complaint_a_id < complaint_b_id), unique(complaint_a_id,complaint_b_id)
);
create table public.deadline_rules (
  id uuid primary key default gen_random_uuid(), name text not null, route text not null, category public.case_category,
  days_to_deadline integer not null check(days_to_deadline > 0), source_citation text not null,
  effective_from date not null, approved_by uuid references public.users(id) on delete restrict, is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.deadlines (
  id uuid primary key default gen_random_uuid(), complaint_id uuid not null references public.complaints(id) on delete restrict,
  rule_id uuid not null references public.deadline_rules(id) on delete restrict, due_at timestamptz not null,
  status public.deadline_status not null default 'on_track', paused_reason text, last_checked_at timestamptz
);
create table public.notification_policies (
  id uuid primary key default gen_random_uuid(), event_type text not null, recipient_role public.app_role not null,
  channel text not null check(channel in ('in_app','email')), template_key text not null, is_active boolean not null default true,
  restricted_case_rule text not null
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete restrict,
  complaint_id uuid references public.complaints(id) on delete restrict, event_type text not null,
  channel text not null check(channel in ('in_app','email')), status text not null,
  idempotency_key text unique not null, sent_at timestamptz, read_at timestamptz, created_at timestamptz not null default now()
);
create table public.policy_chunks (
  id uuid primary key default gen_random_uuid(), document_name text not null, section text not null, page text,
  content_text text not null, embedding extensions.vector(768) not null, indexed_at timestamptz not null default now()
);
create table public.report_runs (
  id uuid primary key default gen_random_uuid(), report_type text not null, requested_by uuid not null references public.users(id) on delete restrict,
  params jsonb not null default '{}', status text not null, file_path text, generated_at timestamptz, created_at timestamptz not null default now()
);
create table public.audit_events (
  id uuid primary key default gen_random_uuid(), actor_id uuid references public.users(id) on delete restrict,
  action text not null, resource_type text not null, resource_id uuid, old_value jsonb, new_value jsonb,
  ip_address inet, session_id uuid, reason text, event_at timestamptz not null default now()
);
create index audit_events_actor_at_idx on public.audit_events(actor_id,event_at desc);
create table public.user_sessions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.users(id) on delete restrict,
  auth_session_id uuid not null unique, user_agent text, ip_address inet, first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(), revoked_at timestamptz
);

create or replace function public.handle_auth_user_profile()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.users(id,email,display_name)
  values(new.id,new.email,coalesce(new.raw_user_meta_data->>'name',new.email,'User'))
  on conflict(id) do update set email=excluded.email, updated_at=now();
  return new;
end;
$$;
create trigger nyayasetu_sync_auth_user_profile after insert or update of email on auth.users
  for each row execute function public.handle_auth_user_profile();
insert into public.users(id,email,display_name)
select id,email,coalesce(raw_user_meta_data->>'name',email,'User') from auth.users
on conflict(id) do update set email=excluded.email, updated_at=now();

create or replace function public.has_any_role(roles public.app_role[])
returns boolean language sql stable security definer set search_path = public, pg_temp set row_security = off as $$
  select exists(select 1 from public.role_assignments ra join public.users u on u.id=ra.user_id
    where ra.user_id=auth.uid() and ra.revoked_at is null and u.is_active and ra.role=any(roles)
      and (ra.role not in ('college_management','pgrc_triage_officer','bureau_officer','regional_officer','bureau_head','competent_authority','ombudsperson','auditor','system_admin') or auth.jwt()->>'aal'='aal2'))
$$;
create or replace function public.has_role_in_bureau(roles public.app_role[], target_bureau text)
returns boolean language sql stable security definer set search_path = public, pg_temp set row_security = off as $$
  select exists(select 1 from public.role_assignments ra join public.users u on u.id=ra.user_id
    where ra.user_id=auth.uid() and ra.revoked_at is null and u.is_active and ra.role=any(roles)
      and ra.bureau=target_bureau and auth.jwt()->>'aal'='aal2')
$$;
create or replace function public.can_read_complaint(target_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp set row_security = off as $$
  select exists(
    select 1 from public.complaints c where c.id=target_id and exists(select 1 from public.users active_user where active_user.id=auth.uid() and active_user.is_active) and (
      (c.submitted_by=auth.uid())
      or (not c.is_confidential and exists(select 1 from public.participants p where p.complaint_id=c.id and p.user_id=auth.uid() and p.removed_at is null))
      or (c.status in ('submitted','under_triage') and public.has_any_role(array['pgrc_triage_officer']::public.app_role[]))
      or public.has_role_in_bureau(array['bureau_officer','bureau_head']::public.app_role[],c.assigned_bureau)
      or (c.appeal_status in ('submitted','under_review','decided') and public.has_any_role(array['ombudsperson']::public.app_role[]))
      or exists(select 1 from public.role_assignments ra join public.users u on u.id=ra.user_id and u.is_active join public.institutions i on i.id=c.institution_id where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role='regional_officer' and ra.region=i.region and auth.jwt()->>'aal'='aal2')
      or (not c.involves_management and not c.is_confidential and exists(select 1 from public.role_assignments ra join public.users u on u.id=ra.user_id and u.is_active where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role='college_management' and ra.institution_id=c.institution_id and auth.jwt()->>'aal'='aal2') and c.status in ('referred','awaiting_response'))
    )
  )
$$;

alter table public.institutions enable row level security;
alter table public.users enable row level security;
alter table public.role_assignments enable row level security;
alter table public.affiliations enable row level security;
alter table public.roster_versions enable row level security;
alter table public.roster_rows enable row level security;
alter table public.verification_attempts enable row level security;
alter table public.complaints enable row level security;
alter table public.participants enable row level security;
alter table public.evidence enable row level security;
alter table public.case_events enable row level security;
alter table public.overlap_alerts enable row level security;
alter table public.case_links enable row level security;
alter table public.dismissed_pairs enable row level security;
alter table public.deadline_rules enable row level security;
alter table public.deadlines enable row level security;
alter table public.notification_policies enable row level security;
alter table public.notifications enable row level security;
alter table public.policy_chunks enable row level security;
alter table public.report_runs enable row level security;
alter table public.audit_events enable row level security;
alter table public.user_sessions enable row level security;

create policy institutions_read_authenticated on public.institutions for select to authenticated using(deleted_at is null);
create policy institutions_admin_write on public.institutions for all to authenticated using(public.has_any_role(array['system_admin']::public.app_role[])) with check(public.has_any_role(array['system_admin']::public.app_role[]));
create policy users_read_self_or_admin on public.users for select to authenticated using(id=auth.uid() or public.has_any_role(array['system_admin','auditor']::public.app_role[]));
create policy role_assignments_read_self_admin on public.role_assignments for select to authenticated using(user_id=auth.uid() or public.has_any_role(array['system_admin','auditor']::public.app_role[]));
create policy affiliations_self_or_verifier_read on public.affiliations for select to authenticated using(user_id=auth.uid() or public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]));
create policy affiliations_self_insert on public.affiliations for insert to authenticated with check(user_id=auth.uid());
create policy affiliations_verifier_update on public.affiliations for update to authenticated using(public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[])) with check(public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]));
create policy roster_versions_college_scope on public.roster_versions for select to authenticated using(exists(select 1 from public.role_assignments ra join public.users u on u.id=ra.user_id and u.is_active where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role in ('college_management','system_admin') and ra.institution_id=roster_versions.institution_id and auth.jwt()->>'aal'='aal2'));
create policy roster_versions_upload on public.roster_versions for insert to authenticated with check(uploaded_by=auth.uid() and exists(select 1 from public.role_assignments ra join public.users u on u.id=ra.user_id and u.is_active where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role='college_management' and ra.institution_id=roster_versions.institution_id and auth.jwt()->>'aal'='aal2'));
create policy roster_rows_college_scope on public.roster_rows for select to authenticated using(exists(select 1 from public.roster_versions rv join public.role_assignments ra on ra.institution_id=rv.institution_id join public.users u on u.id=ra.user_id and u.is_active where rv.id=roster_rows.version_id and ra.user_id=auth.uid() and ra.revoked_at is null and ra.role in ('college_management','system_admin') and auth.jwt()->>'aal'='aal2'));
create policy verification_attempts_authorized_read on public.verification_attempts for select to authenticated using(exists(select 1 from public.affiliations a where a.id=verification_attempts.affiliation_id and a.user_id=auth.uid()) or public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]));
create policy verification_attempts_verifier_insert on public.verification_attempts for insert to authenticated with check(reviewed_by=auth.uid() and public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]));

create policy complaints_scoped_read on public.complaints for select to authenticated using(public.can_read_complaint(id));
create policy complaints_student_insert on public.complaints for insert to authenticated with check(submitted_by=auth.uid() and status='submitted' and public.has_any_role(array['student']::public.app_role[]) and exists(select 1 from public.affiliations a where a.user_id=auth.uid() and a.institution_id=complaints.institution_id and a.status='verified'));
create policy complaints_ai_update on public.complaints for update to authenticated using(
  (status in ('submitted','under_triage') and public.has_any_role(array['pgrc_triage_officer']::public.app_role[]))
  or public.has_role_in_bureau(array['bureau_officer','bureau_head']::public.app_role[],assigned_bureau)
) with check(
  public.has_any_role(array['pgrc_triage_officer','bureau_officer','bureau_head']::public.app_role[])
);
create policy participants_case_scope_read on public.participants for select to authenticated using(public.can_read_complaint(complaint_id));
create policy participants_ai_manage on public.participants for all to authenticated using(public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[])) with check(public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]));
create policy evidence_case_scope_read on public.evidence for select to authenticated using(public.can_read_complaint(complaint_id));
create policy evidence_case_insert on public.evidence for insert to authenticated with check(uploaded_by=auth.uid() and public.can_read_complaint(complaint_id));
create policy case_events_scope_read on public.case_events for select to authenticated using(public.can_read_complaint(complaint_id) and (visibility='public' or (visibility='complainant' and exists(select 1 from public.complaints c where c.id=complaint_id and c.submitted_by=auth.uid())) or (visibility='college' and exists(select 1 from public.role_assignments ra join public.complaints c on c.institution_id=ra.institution_id where c.id=complaint_id and ra.user_id=auth.uid() and ra.revoked_at is null and ra.role='college_management')) or public.has_any_role(array['pgrc_triage_officer','bureau_officer','bureau_head','regional_officer','competent_authority','ombudsperson','auditor','system_admin']::public.app_role[])));
create policy overlap_alerts_ai_read on public.overlap_alerts for select to authenticated using(public.has_any_role(array['pgrc_triage_officer','bureau_officer','bureau_head']::public.app_role[]));
create policy overlap_alerts_ai_update on public.overlap_alerts for update to authenticated using(public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[])) with check(public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]));
create policy case_links_ai_read on public.case_links for select to authenticated using(public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]) or (public.can_read_complaint(complaint_a_id) and public.can_read_complaint(complaint_b_id)));
create policy case_links_ai_insert on public.case_links for insert to authenticated with check(linked_by=auth.uid() and public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]));
create policy dismissed_pairs_ai_scope on public.dismissed_pairs for select to authenticated using(public.has_any_role(array['pgrc_triage_officer','bureau_head']::public.app_role[]) or (public.can_read_complaint(complaint_a_id) and public.can_read_complaint(complaint_b_id)));
create policy deadline_rules_read on public.deadline_rules for select to authenticated using(true);
create policy deadline_rules_admin on public.deadline_rules for all to authenticated using(public.has_any_role(array['pgrc_triage_officer','bureau_head','system_admin']::public.app_role[])) with check(public.has_any_role(array['pgrc_triage_officer','bureau_head','system_admin']::public.app_role[]));
create policy deadlines_case_scope on public.deadlines for select to authenticated using(public.can_read_complaint(complaint_id));
create policy notification_policies_admin on public.notification_policies for select to authenticated using(public.has_any_role(array['system_admin']::public.app_role[]));
create policy notifications_self_read on public.notifications for select to authenticated using(user_id=auth.uid());
create policy notifications_self_update on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy policy_chunks_authenticated_read on public.policy_chunks for select to authenticated using(true);
create policy report_runs_scoped_read on public.report_runs for select to authenticated using(requested_by=auth.uid());
create policy audit_events_admin_read on public.audit_events for select to authenticated using(public.has_any_role(array['auditor','system_admin']::public.app_role[]));
create policy user_sessions_self_read on public.user_sessions for select to authenticated using(user_id=auth.uid());

-- Direct authenticated writes are limited to self-service inserts/updates; sensitive mutations go through server-only RPCs.
revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
grant select on public.institutions, public.users, public.role_assignments, public.affiliations, public.roster_versions,
  public.roster_rows, public.verification_attempts, public.complaints, public.participants, public.evidence,
  public.case_events, public.overlap_alerts, public.case_links, public.dismissed_pairs, public.deadline_rules,
  public.deadlines, public.notification_policies, public.notifications, public.policy_chunks, public.report_runs,
  public.audit_events, public.user_sessions to authenticated;
grant insert (user_id,institution_id,type,enrollment_no,programme,year) on public.affiliations to authenticated;
grant insert (institution_id,uploaded_by,row_count,file_path,version_label) on public.roster_versions to authenticated;
grant insert (institution_id,submitted_by,category,secondary_category,description_text,description_language,is_confidential) on public.complaints to authenticated;
grant insert on public.verification_attempts to authenticated;
grant update (read_at) on public.notifications to authenticated;
revoke insert, update, delete, truncate on public.case_events, public.audit_events from anon, authenticated;
revoke update on public.complaints from anon, authenticated;
revoke all on public.user_sessions from anon, authenticated;
grant select on public.user_sessions to authenticated;

-- Private evidence bucket. Storage RLS must still validate complaint access in application-generated signed URLs.
insert into storage.buckets(id,name,public,file_size_limit) values('case-evidence','case-evidence',false,10485760) on conflict(id) do nothing;
create policy case_evidence_authenticated_read on storage.objects for select to authenticated using(bucket_id='case-evidence' and exists(select 1 from public.evidence e where e.file_path=name and public.can_read_complaint(e.complaint_id)));
create policy case_evidence_authenticated_insert on storage.objects for insert to authenticated with check(bucket_id='case-evidence' and name ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/' and exists(select 1 from public.complaints c where c.id=split_part(name,'/',1)::uuid and public.can_read_complaint(c.id)));

-- Role changes must be made through trusted service-side administration code, with audit rows in the same workflow.
revoke insert, update, delete on public.role_assignments from anon, authenticated;

create or replace function public.admin_grant_role(p_user_id uuid, p_role public.app_role, p_institution_id uuid, p_bureau text, p_region text, p_granted_by uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare new_assignment public.role_assignments;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'service role required'; end if;
  insert into public.role_assignments(user_id,role,institution_id,bureau,region,granted_by,reason)
  values(p_user_id,p_role,p_institution_id,p_bureau,p_region,p_granted_by,p_reason) returning * into new_assignment;
  insert into public.audit_events(actor_id,action,resource_type,resource_id,new_value,reason)
  values(p_granted_by,'role.granted','role_assignment',new_assignment.id,to_jsonb(new_assignment),p_reason);
  return to_jsonb(new_assignment);
end;
$$;
create or replace function public.admin_revoke_role(p_assignment_id uuid, p_revoked_by uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare old_assignment public.role_assignments; new_assignment public.role_assignments;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'service role required'; end if;
  select * into old_assignment from public.role_assignments where id=p_assignment_id and revoked_at is null for update;
  if not found then raise exception 'active role assignment not found'; end if;
  update public.role_assignments set revoked_at=now(), reason=p_reason where id=p_assignment_id returning * into new_assignment;
  insert into public.audit_events(actor_id,action,resource_type,resource_id,old_value,new_value,reason)
  values(p_revoked_by,'role.revoked','role_assignment',p_assignment_id,to_jsonb(old_assignment),to_jsonb(new_assignment),p_reason);
  return to_jsonb(new_assignment);
end;
$$;
revoke all on function public.admin_grant_role(uuid,public.app_role,uuid,text,text,uuid,text) from public, anon, authenticated;
revoke all on function public.admin_revoke_role(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_grant_role(uuid,public.app_role,uuid,text,text,uuid,text) to service_role;
grant execute on function public.admin_revoke_role(uuid,uuid,text) to service_role;

