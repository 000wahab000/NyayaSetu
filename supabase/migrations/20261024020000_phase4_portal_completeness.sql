-- Additive support for the extended Phase 4 portal workflows.
create or replace function public.can_read_complaint(target_id uuid)
returns boolean language sql stable security definer
set search_path = public, pg_temp set row_security = off as $$
  select exists(
    select 1 from public.complaints c
    where c.id=target_id and exists(select 1 from public.users u where u.id=auth.uid() and u.is_active)
      and (c.submitted_by=auth.uid()
        or (not c.is_confidential and exists(select 1 from public.participants p where p.complaint_id=c.id and p.user_id=auth.uid() and p.role='faculty' and p.removed_at is null))
        or (c.status::text in ('submitted','under_triage') and exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='pgrc_triage_officer' and auth.jwt()->>'aal'='aal2'))
        or exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text in ('bureau_officer','bureau_head') and ra.bureau=c.assigned_bureau and auth.jwt()->>'aal'='aal2')
        or (c.appeal_status::text in ('submitted','under_review','decided') and exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='ombudsperson' and auth.jwt()->>'aal'='aal2'))
        or exists(select 1 from public.role_assignments ra join public.institutions i on i.id=c.institution_id where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='regional_officer' and ra.region=i.region and auth.jwt()->>'aal'='aal2')
        or (not c.involves_management and not c.is_confidential and c.status::text in ('referred','awaiting_response','under_examination') and exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='college_management' and ra.institution_id=c.institution_id and auth.jwt()->>'aal'='aal2'))
        or exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text in ('competent_authority','auditor','system_admin') and auth.jwt()->>'aal'='aal2'))
  )
$$;

drop policy if exists faculty_complaints_select on public.complaints;
create policy faculty_complaints_select on public.complaints for select to authenticated using(
  not is_confidential and exists(select 1 from public.participants p where p.complaint_id=complaints.id
    and p.user_id=auth.uid() and p.role='faculty' and p.removed_at is null)
);

create table if not exists public.hearings (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.complaints(id) on delete restrict,
  scheduled_by uuid not null references public.users(id) on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  meeting_url text,
  status text not null default 'scheduled' check(status in ('scheduled','completed','cancelled')),
  created_at timestamptz not null default now(),
  check(ends_at is null or ends_at > starts_at),
  check(meeting_url is null or meeting_url like 'https://%')
);
create index if not exists hearings_case_start_idx on public.hearings(complaint_id,starts_at);
alter table public.hearings enable row level security;
drop policy if exists hearings_case_scope_read on public.hearings;
create policy hearings_case_scope_read on public.hearings for select to authenticated using(public.can_read_complaint(complaint_id));
revoke insert,update,delete,truncate on public.hearings from anon,authenticated;
grant select on public.hearings to authenticated;

create table if not exists public.case_feedback (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.complaints(id) on delete restrict,
  submitted_by uuid not null references public.users(id) on delete restrict,
  rating smallint not null check(rating between 1 and 5),
  comment text check(comment is null or char_length(comment)<=2000),
  submitted_at timestamptz not null default now(),
  unique(complaint_id,submitted_by)
);
alter table public.case_feedback enable row level security;
drop policy if exists case_feedback_self_read on public.case_feedback;
create policy case_feedback_self_read on public.case_feedback for select to authenticated using(submitted_by=auth.uid());
revoke insert,update,delete,truncate on public.case_feedback from anon,authenticated;
grant select on public.case_feedback to authenticated;

create table if not exists public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  request_type text not null check(request_type in ('data_export','rectification','account_closure')),
  details text check(details is null or char_length(details)<=2000),
  status text not null default 'submitted' check(status in ('submitted','in_review','completed','declined')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.users(id) on delete restrict
);
alter table public.privacy_requests enable row level security;
drop policy if exists privacy_requests_self_read on public.privacy_requests;
create policy privacy_requests_self_read on public.privacy_requests for select to authenticated using(user_id=auth.uid());
revoke insert,update,delete,truncate on public.privacy_requests from anon,authenticated;
grant select on public.privacy_requests to authenticated;
