import "server-only";
import { createAdminClient } from "@/lib/supabase/admin";

export type AuditPayload = {
  actor_id?: string | null; action: string; resource_type: string; resource_id?: string | null;
  old_value?: unknown; new_value?: unknown; reason?: string | null; session_id?: string | null; ip?: string | null;
};

/** Audit writes are awaited. A failed audit write fails the sensitive operation closed. */
export async function auditLog(payload: AuditPayload) {
  const supabase = createAdminClient();
  const { error } = await supabase.from("audit_events").insert({
    actor_id: payload.actor_id ?? null, action: payload.action, resource_type: payload.resource_type,
    resource_id: payload.resource_id ?? null, old_value: payload.old_value ?? null,
    new_value: payload.new_value ?? null, reason: payload.reason ?? null,
    session_id: payload.session_id ?? null, ip_address: payload.ip ?? null, event_at: new Date().toISOString(),
  });
  if (error) throw new Error(`Audit write failed: ${error.message}`);
}
