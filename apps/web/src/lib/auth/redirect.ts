import { hasRequiredMfa, ROLE_HOME } from "@/lib/auth/roles";
import type { AppSession } from "@/lib/auth/session";

export function destinationFor(session: AppSession) {
  if (!hasRequiredMfa(session.role, session.aal)) return "/auth/totp";
  return ROLE_HOME[session.role];
}
