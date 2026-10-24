create extension if not exists pgtap with schema extensions;
begin;
select plan(16);

insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('10000000-0000-4000-8000-000000000001','authenticated','authenticated','rls-student-a@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000002','authenticated','authenticated','rls-student-b@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000003','authenticated','authenticated','rls-college@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000004','authenticated','authenticated','rls-rb@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000005','authenticated','authenticated','rls-pgrc@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000006','authenticated','authenticated','rls-faculty@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000007','authenticated','authenticated','rls-region@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000008','authenticated','authenticated','rls-authority@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000009','authenticated','authenticated','rls-ombuds@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000010','authenticated','authenticated','rls-auditor@example.test','',now(),'{}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000011','authenticated','authenticated','rls-admin@example.test','',now(),'{}','{}',now(),now());

insert into public.institutions(id,aicte_permanent_id,name,region,type) values
 ('20000000-0000-4000-8000-000000000001','DEMO-RLS-001','RLS Institution One','North','college'),
 ('20000000-0000-4000-8000-000000000002','DEMO-RLS-002','RLS Institution Two','South','college');
insert into public.role_assignments(user_id,role,institution_id,bureau,region,reason) values
 ('10000000-0000-4000-8000-000000000001','student','20000000-0000-4000-8000-000000000001',null,null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000002','student','20000000-0000-4000-8000-000000000002',null,null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000003','college_management','20000000-0000-4000-8000-000000000001',null,null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000004','bureau_officer',null,'RB',null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000005','pgrc_triage_officer',null,'PGRC',null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000006','faculty','20000000-0000-4000-8000-000000000001',null,null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000007','regional_officer',null,null,'North','RLS fixture'),
 ('10000000-0000-4000-8000-000000000008','competent_authority',null,null,null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000009','ombudsperson',null,null,null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000010','auditor',null,null,null,'RLS fixture'),
 ('10000000-0000-4000-8000-000000000011','system_admin',null,null,null,'RLS fixture');
insert into public.affiliations(user_id,institution_id,type,status) values
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','current_student','verified'),
 ('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','current_student','verified'),
 ('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','current_student','verified');
insert into public.complaints(id,case_id,institution_id,submitted_by,category,description_text,status,assigned_bureau,involves_management) values
 ('30000000-0000-4000-8000-000000000001','RLS-CASE-001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','academic',repeat('Student complaint detail. ',3),'submitted',null,false),
 ('30000000-0000-4000-8000-000000000002','RLS-CASE-002','20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','academic',repeat('Another student complaint. ',3),'submitted',null,false),
 ('30000000-0000-4000-8000-000000000003','RLS-CASE-003','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','financial',repeat('Referred complaint response. ',3),'referred',null,false),
 ('30000000-0000-4000-8000-000000000004','RLS-CASE-004','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','financial',repeat('Management complaint detail. ',3),'referred',null,true),
 ('30000000-0000-4000-8000-000000000005','RLS-CASE-005','20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','infrastructure',repeat('Assigned Bureau case detail. ',3),'under_examination','RB',false),
 ('30000000-0000-4000-8000-000000000006','RLS-CASE-006','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','academic',repeat('Appeal case detail. ',4),'appeal_submitted',null,false),
 ('30000000-0000-4000-8000-000000000007','RLS-CASE-007','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','ragging',repeat('Confidential case detail. ',3),'referred',null,false);
update public.complaints set appeal_status='submitted' where id='30000000-0000-4000-8000-000000000006';
update public.complaints set is_confidential=true where id='30000000-0000-4000-8000-000000000007';
insert into public.participants(complaint_id,user_id,role,access_scope) values
 ('30000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006','faculty','full');

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),1,'student sees only own case');
select throws_ok($$insert into public.complaints(institution_id,submitted_by,category,description_text) values('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','academic',repeat('Invalid cross institution complaint. ',3))$$,'42501',null,'student cannot submit against another institution without verified affiliation');
select throws_ok($$update public.case_events set remarks='tampered'$$,'42501',null,'case event update is denied');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),0,'college role without AAL2 sees no referred cases');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),1,'college sees referred case but not management case');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),1,'Bureau officer sees only assigned Bureau cases');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","role":"authenticated","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),2,'PGRC sees intake and triage cases only');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000006","role":"authenticated","aal":"aal1"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),1,'faculty sees only an actively assigned case');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000007","role":"authenticated","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),5,'regional officer sees cases in own region');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000008","role":"authenticated","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),0,'competent authority cannot read complaint details');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),1,'ombudsperson sees only appeal cases');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),0,'auditor cannot read complaint details');
reset role;

select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000011","role":"authenticated","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.complaints),0,'system administrator cannot read complaint details');
reset role;

select ok(not has_table_privilege('authenticated','public.case_events','UPDATE'),'authenticated cannot update case events');
select ok(not has_table_privilege('authenticated','public.audit_events','DELETE'),'authenticated cannot delete audit events');
select ok((select count(*) >= 22 from pg_class where relnamespace='public'::regnamespace and relkind='r' and relrowsecurity),'all application tables have row-level security');
select * from finish();
rollback;
