# NyayaSetu permission matrix

Legend: **C** = allowed; **N** = denied; **Cond.** = allowed only under the stated scope/condition. Server authorization and PostgreSQL RLS must enforce the same rules. Scope is always applied to every allowed read/write.

Roles: Student/Alumnus; Faculty/Committee; College Management; PGRC Triage; Bureau Officer (including RB/other cells); Regional Officer; Bureau Head/Adviser; Competent Authority; Ombudsperson; Auditor/System Admin.

| Resource / action | Student | Faculty | College Mgmt | PGRC Triage | Bureau Officer | Regional Officer | Bureau Head | Competent Authority | Ombudsperson | Auditor/Admin |
|---|---|---|---|---|---|---|---|---|---|---|
| Institutions: read profile | Cond. own institution public/profile fields | Cond. own institution | C assigned institution | C | C | Cond. region | C | C | C | C |
| Institutions: modify profile/roster | N | N | Cond. own institution profile and versioned roster | C verification/master data | N | N | C with reason | N | Cond. configuration only, reason required |
| Users/roles: read directory | N | Cond. own committee directory | Cond. own institution roster | C operational scope | Cond. assigned Bureau | Cond. region | C | C read-only | Cond. appeal parties | C |
| Users/roles: grant/revoke roles | N | N | N | N | N | N | N | N | N | Cond. role/configuration action with reason and audit |
| Complaints: read details | Cond. own complaint; sensitive fields limited to complainant view | Cond. personally assigned, no recused/self-related case | Cond. referred cases only; never management-involved cases | C triage scope; confidential identity only for authorized officers | Cond. assigned Bureau/participant | Cond. region and assigned scope | C all authorized Bureau scope | Cond. appeal queue and record needed | N (audit log only) |
| Complaints: submit/create | C own complaint | N | N | C intake/on-behalf-of with source recorded | N | N | N | N | N | N |
| Complaints: edit content/category | N after submit; may add clarification | N | N | Cond. triage correction with event | Cond. assigned case action, category correction event | Cond. field note only | Cond. reassign/escalate with reason | N | N | N |
| Complaints: change lifecycle state | N | N | N | Cond. allowed state transitions | Cond. assigned case transitions | N | Cond. transitions/reopen/escalate | N | Cond. appeal transitions only | N |
| Complaints: assign/transfer Bureau/officer | N | N | N | C initial routing/assignment | Cond. request transfer; no unilateral cross-Bureau transfer | N | C approve/reassign, reason required | N | N | N |
| Complaints: delete | N | N | N | N | N | N | N | N | N | N |
| College response | N | Cond. assigned response, factual response/evidence/internal notes | Cond. referred case; assign committee and submit official response | C review | C review | N | C review/escalate | N | N | N |
| Evidence: read/download | Cond. own submitted evidence | Cond. assigned case, no recusal; scoped | Cond. referred response evidence; not complainant identity if confidential | C authorized triage | Cond. assigned Bureau | Cond. authorized region case | C scope | Cond. appeal record | N | Cond. access audit metadata only; no default content |
| Evidence: upload | C to own open complaint | Cond. assigned case response | Cond. referred response | Cond. intake/official record | Cond. assigned case | Cond. field note only | Cond. authorized case action | N | Cond. appeal evidence | N |
| Affiliation: read/update own claim | C own | Cond. own affiliation | Cond. institution roster verification data, not complaint text | C verification queue | N | N | Cond. oversight | N | N | Cond. audit metadata |
| Verification: decide | N | N | N (may upload roster only) | C | N | N | Cond. review/override with reason | N | N | N |
| Case events: read | Cond. own visible timeline; omit internal notes | Cond. assigned actions; exclude restricted internals | Cond. referred response-visible events only | C case scope | C assigned scope | Cond. region scope | C scope | Cond. appeal scope | N | Cond. audit events only |
| Case events: append action | Cond. clarification/feedback/appeal request | Cond. assigned response/hearing | Cond. referral response/assignment | C triage actions | C assigned actions | Cond. field notes | C administrative actions | N | C appeal decision | N |
| Overlap alerts/links | N | N | N | C review/link/dismiss with reason | Cond. view assigned Bureau alerts; propose action | N | C reopen/resolve/lead Bureau | Cond. read-only aggregate | N | N |
| Deadlines | Cond. own next expected date | Cond. assigned tasks | Cond. referred-case deadlines | C configure/apply | Cond. assigned case | Cond. regional view | C configure/reassign/escalate | Cond. aggregate read | N | Cond. audit metadata |
| Notifications/preferences | C own | C own | C own | C own | C own | C own | C own | C own | C own | C own |
| Reports/exports | N | N | Cond. own institution compliance aggregates, no restricted cases | C authorized scope | Cond. assigned Bureau | Cond. region | C authorized scope | C read-only aggregate | Cond. appeal aggregate | Cond. system audit reports only |
| RAG policy assistant | N | N | N | C | C | C | C | C | C | C |
| Audit trail: read | N | N | N | Cond. case action history, not system security logs | Cond. case action history | Cond. own region action history | Cond. Bureau actions | Cond. read-only dashboard | Cond. appeal actions | C |
| Audit/configuration: modify | N | N | N | N | N | N | N | N | N | Cond. config only; reason mandatory; never case content |

## Global conditions

1. A row marked **Cond.** requires both role and case scope; an assignment does not override recusal, self-involvement, confidentiality, or management-involvement restrictions.
2. Confidential complaints reveal identity only to specifically authorized AICTE officers. The college and its management receive redacted response views where policy permits.
3. A complaint involving institution management is never visible or notified to that institution's management accounts; it follows the independent AICTE route.
4. Faculty recusal immediately removes case access and prevents subsequent reads/writes; reassignment and reason are audited.
5. Competent Authority is read-only. Auditor/System Admin can inspect audit/configuration surfaces but cannot modify cases or read complaint contents by default.
6. Every write action creates a `case_events` or `audit_events` record. No role can delete complaints, evidence history, or events through the application.
