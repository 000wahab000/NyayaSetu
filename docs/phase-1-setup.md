# Phase 1 deployment and first administrator

## Local app setup

1. Copy `apps/web/.env.example` to `apps/web/.env.local`; fill in the Supabase project URL, anon key, and service-role key. `AUTH_SECRET` is retained for the frozen plan; Supabase manages the auth session signing key.
2. From the repository root, run `npm install`, then `npm run dev`.
3. Ensure Supabase Auth has email OTP enabled with confirmations disabled. In Auth → Email Templates → Magic Link, include the numeric OTP placeholder `{{ .Token }}` so the app's code-entry screen receives a code. Phone OTP is intentionally disabled for the free MVP. Enable TOTP enrollment and verification in Auth → MFA. Add `http://localhost:3000/**` and the deployed app callback URLs to Auth redirect URLs.

## Database deployment

Review the intended Supabase ref in the CLI's linked-project metadata before deploying. The migration is `supabase/migrations/20261024000000_phase1_foundation.sql`. The Supabase CLI is pinned as a root dev dependency; run `npx supabase login` and `npx supabase db push` from the repository root. Do not paste service-role keys in SQL, chat, commits, or logs.

## Bootstrap the first system administrator

Create the initial account through Supabase Auth (email OTP user or dashboard invitation), then run this one-time SQL in the Supabase SQL Editor after replacing the UUID with that account's Auth user UUID. Use only a trusted operator account. This bootstrap is intentionally manual because no account can safely self-grant `system_admin`.

```sql
insert into public.users (id, email, display_name)
select id, email, coalesce(raw_user_meta_data->>'name', email)
from auth.users where id = 'REPLACE-WITH-AUTH-USER-UUID'::uuid
on conflict (id) do update set email=excluded.email, display_name=excluded.display_name;

insert into public.role_assignments (user_id, role, granted_by, reason)
values ('REPLACE-WITH-AUTH-USER-UUID'::uuid, 'system_admin', 'REPLACE-WITH-AUTH-USER-UUID'::uuid, 'Initial trusted administrator bootstrap');

insert into public.audit_events (actor_id, action, resource_type, resource_id, reason)
select id, 'role.granted', 'role_assignment', (select id from public.role_assignments where user_id=auth.users.id and role='system_admin' and revoked_at is null limit 1), 'Initial trusted administrator bootstrap'
from auth.users where id = 'REPLACE-WITH-AUTH-USER-UUID'::uuid;
```

The initial system administrator must enroll TOTP at first access. Subsequent role grants/revocations use the audited admin API. Add a user profile and role assignment for every demo account before login; OTP signup is closed.

## Operational boundary

The migration is not applied to a hosted project by this source change. Hosted deployment requires the CLI or SQL Editor and a human review of the project ref. Configure SMTP for production-quality OTP delivery; Supabase's built-in email service has low-volume limits. No paid provider is required for local development, but free-tier availability and limits vary.
