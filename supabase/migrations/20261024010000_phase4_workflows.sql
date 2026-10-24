-- Phase 4 database support. The linked project already has the earlier complaint
-- tables from packages/db migrations; these additive changes also support a fresh
-- install created from the Phase 1 foundation migration.

-- Match the Phase 4 intake contract (10–10,000 characters).
alter table public.complaints drop constraint if exists complaints_description_text_check;
alter table public.complaints add constraint complaints_description_text_check
  check (char_length(description_text) between 10 and 10000);

-- The current app's session guard uses this table; it was missing from the linked DB.
create table if not exists public.user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  auth_session_id uuid not null unique,
  user_agent text,
  ip_address inet,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz
);
alter table public.user_sessions enable row level security;
drop policy if exists user_sessions_self_read on public.user_sessions;
create policy user_sessions_self_read on public.user_sessions for select to authenticated using(user_id=auth.uid());
revoke all on public.user_sessions from anon, authenticated;
grant select on public.user_sessions to authenticated;

-- Keep event visibility available on the existing case_events table.
alter table public.case_events add column if not exists visibility text not null default 'internal';
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid='public.case_events'::regclass and conname='case_events_visibility_check') then
    alter table public.case_events add constraint case_events_visibility_check
      check (visibility in ('internal','complainant','college','public'));
  end if;
end $$;

-- A shared, row-security-safe case visibility predicate compatible with both
-- enum and text role columns in existing and fresh databases.
create or replace function public.can_read_complaint(target_id uuid)
returns boolean language sql stable security definer
set search_path = public, pg_temp set row_security = off as $$
  select exists(
    select 1 from public.complaints c
    where c.id=target_id
      and exists(select 1 from public.users u where u.id=auth.uid() and u.is_active)
      and (
        c.submitted_by=auth.uid()
        or (c.status::text in ('submitted','under_triage') and exists(
          select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='pgrc_triage_officer' and auth.jwt()->>'aal'='aal2'))
        or exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text in ('bureau_officer','bureau_head') and ra.bureau=c.assigned_bureau and auth.jwt()->>'aal'='aal2')
        or (c.appeal_status::text in ('submitted','under_review','decided') and exists(
          select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='ombudsperson' and auth.jwt()->>'aal'='aal2'))
        or exists(select 1 from public.role_assignments ra join public.institutions i on i.id=c.institution_id where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='regional_officer' and ra.region=i.region and auth.jwt()->>'aal'='aal2')
        or (not c.involves_management and not c.is_confidential
          and c.status::text in ('referred','awaiting_response','under_examination')
          and exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='college_management' and ra.institution_id=c.institution_id and auth.jwt()->>'aal'='aal2'))
        or exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text in ('competent_authority','auditor','system_admin') and auth.jwt()->>'aal'='aal2')
      )
  )
$$;

-- The original deployed policy included management-free cases but did not exclude
-- confidential cases or match the Phase 4 status window. Tighten that policy.
drop policy if exists college_management_complaints_select on public.complaints;
create policy college_management_complaints_select on public.complaints for select to authenticated using(
  not involves_management and not is_confidential
  and status::text in ('referred','awaiting_response','under_examination')
  and exists(select 1 from public.role_assignments ra join public.users u on u.id=ra.user_id and u.is_active
    where ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='college_management'
      and ra.institution_id=complaints.institution_id and auth.jwt()->>'aal'='aal2')
);

-- Apply visibility filters at the database boundary, not only in page code.
drop policy if exists case_events_select on public.case_events;
drop policy if exists case_events_scope_read on public.case_events;
drop policy if exists case_events_phase4_select on public.case_events;
create policy case_events_phase4_select on public.case_events for select to authenticated using(
  public.can_read_complaint(complaint_id)
  and (
    visibility='public'
    or (visibility='complainant' and exists(select 1 from public.complaints c where c.id=complaint_id and c.submitted_by=auth.uid()))
    or (visibility='college' and exists(select 1 from public.complaints c join public.role_assignments ra on ra.institution_id=c.institution_id
      join public.users u on u.id=ra.user_id and u.is_active where c.id=complaint_id and not c.involves_management and not c.is_confidential
        and c.status::text in ('referred','awaiting_response','under_examination') and ra.user_id=auth.uid()
        and ra.revoked_at is null and ra.role::text='college_management' and auth.jwt()->>'aal'='aal2'))
    or (visibility='internal' and exists(select 1 from public.role_assignments ra where ra.user_id=auth.uid() and ra.revoked_at is null
      and ra.role::text in ('pgrc_triage_officer','bureau_officer','bureau_head','regional_officer','competent_authority','ombudsperson','auditor','system_admin')
      and auth.jwt()->>'aal'='aal2'))
  )
);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('institution-rosters','institution-rosters',false,5242880,array['text/csv','application/vnd.ms-excel'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists institution_rosters_college_read on storage.objects;
create policy institution_rosters_college_read on storage.objects for select to authenticated
using(bucket_id='institution-rosters' and exists(
  select 1 from public.roster_versions rv join public.role_assignments ra on ra.institution_id=rv.institution_id
  join public.users u on u.id=ra.user_id and u.is_active
  where rv.file_path=name and ra.user_id=auth.uid() and ra.revoked_at is null and ra.role::text='college_management'
    and auth.jwt()->>'aal'='aal2'
));
