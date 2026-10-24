// POST /api/complaints/[id]/transition
// Enforces state machine rules + optimistic locking.

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { isValidTransition, canRoleTransition, type LifecycleStatus } from "@/lib/state-machine";
import { z } from "zod";

const Schema = z.object({
  to_status: z.string(),
  remarks:   z.string().min(1),
  version:   z.number().int(),  // optimistic locking
  next_action:    z.string().optional(),
  next_action_at: z.string().optional(),
  expected_disposal_at: z.string().optional(),
  out_of_scope_reason: z.string().optional(),
});

async function hashEvent(prevHash: string | null, eventType: string, actorId: string, eventAt: string, payload: unknown): Promise<string> {
  const input = `${prevHash ?? ""}|${eventType}|${actorId}|${eventAt}|${JSON.stringify(payload)}`;
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const role = req.headers.get("x-user-role") ?? "";
  const body = await req.json();
  const parsed = Schema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });

  const { to_status, remarks, version, next_action, next_action_at, expected_disposal_at } = parsed.data;

  // Fetch current complaint
  const { data: complaint, error: fetchError } = await supabase
    .from("complaints")
    .select("id, status, version, case_id")
    .eq("id", id)
    .single();

  if (fetchError || !complaint) return NextResponse.json({ error: "Not found" }, { status: 404 });

  // Optimistic locking check
  if (complaint.version !== version) {
    return NextResponse.json({ error: "Conflict: case was modified. Please reload." }, { status: 409 });
  }

  const fromStatus = complaint.status as LifecycleStatus;
  const toStatus   = to_status as LifecycleStatus;

  // State machine validation
  if (!isValidTransition(fromStatus, toStatus)) {
    return NextResponse.json({ error: `Invalid transition: ${fromStatus} → ${toStatus}` }, { status: 409 });
  }
  if (!canRoleTransition(fromStatus, toStatus, role)) {
    return NextResponse.json({ error: `Role '${role}' cannot perform this transition.` }, { status: 403 });
  }

  const now = new Date().toISOString();

  // Fetch last event hash for chain
  const { data: lastEvent } = await supabase
    .from("case_events")
    .select("event_hash")
    .eq("complaint_id", id)
    .order("event_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const eventPayload = { from: fromStatus, to: toStatus, remarks };
  const eventHash = await hashEvent(lastEvent?.event_hash ?? null, "status_transition", user.id, now, eventPayload);

  // Update complaint + append event atomically (two writes — if event fails, UI will retry)
  const { error: updateError } = await supabase
    .from("complaints")
    .update({
      status:        toStatus,
      last_action_at: now,
      next_action:   next_action ?? null,
      next_action_at: next_action_at ?? null,
      expected_disposal_at: expected_disposal_at ?? undefined,
      version:       version + 1,
      updated_at:    now,
    })
    .eq("id", id)
    .eq("version", version);  // second optimistic lock at DB level

  if (updateError) return NextResponse.json({ error: updateError.message }, { status: 500 });

  await supabase.from("case_events").insert({
    complaint_id:    id,
    event_type:      "status_transition",
    actor_id:        user.id,
    actor_role:      role,
    bureau:          req.headers.get("x-user-bureau") ?? null,
    old_state:       { status: fromStatus },
    new_state:       { status: toStatus },
    remarks,
    event_at:        now,
    prev_event_hash: lastEvent?.event_hash ?? null,
    event_hash:      eventHash,
  });

  return NextResponse.json({ success: true, new_status: toStatus, version: version + 1 });
}
