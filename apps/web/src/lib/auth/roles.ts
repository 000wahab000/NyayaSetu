export const ROLES = [
  "student", "faculty", "college_management", "pgrc_triage_officer", "bureau_officer",
  "regional_officer", "bureau_head", "competent_authority", "ombudsperson", "auditor", "system_admin",
] as const;
export type Role = (typeof ROLES)[number];

export const ROLE_HOME: Record<Role, string> = {
  student: "/student", faculty: "/faculty", college_management: "/college",
  pgrc_triage_officer: "/aicte", bureau_officer: "/aicte", regional_officer: "/aicte",
  bureau_head: "/aicte", competent_authority: "/aicte", ombudsperson: "/aicte",
  auditor: "/aicte", system_admin: "/aicte",
};

export const ROUTE_ROLE: Record<string, Role[]> = {
  "/student": ["student"], "/faculty": ["faculty"], "/college": ["college_management"],
  "/aicte": ["pgrc_triage_officer", "bureau_officer", "regional_officer", "bureau_head", "competent_authority", "ombudsperson", "auditor", "system_admin"],
};

export function hasRequiredMfa(role: Role, aal: string | null | undefined) {
  return !["college_management", "pgrc_triage_officer", "bureau_officer", "regional_officer", "bureau_head", "competent_authority", "ombudsperson", "auditor", "system_admin"].includes(role) || aal === "aal2";
}
