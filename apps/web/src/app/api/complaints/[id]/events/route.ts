// GET /api/complaints/[id]/events — full action history for a case
// POST /api/complaints/[id]/events — append a new action event

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { z } from "zod";

export async function GET(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { data, error } = await supabase
    .from("case_events")
    .select(`*, users!actor_id(display_name)`)
    .eq("complaint_id", id)
    .order("event_at", { ascending: true });

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json({ data });
}

const AppendEventSchema = z.object({
  event_type: z.string().min(1),
  remarks:    z.string().min(1),
  old_state:  z.record(z.string(), z.unknown()).optional(),
  new_state:  z.record(z.string(), z.unknown()).optional(),
  document_ids: z.array(z.string().uuid()).optional(),
});

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const role   = req.headers.get("x-user-role") ?? "";
  const bureau = req.headers.get("x-user-bureau") ?? null;

  const body   = await req.json();
  const parsed = AppendEventSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });

  const { event_type, remarks, old_state, new_state, document_ids } = parsed.data;
  const now = new Date().toISOString();

  // Get last event hash for chain
  const { data: lastEvent } = await supabase
    .from("case_events")
    .select("event_hash")
    .eq("complaint_id", id)
    .order("event_at", { ascending: false })
    .limit(1).maybeSingle();

  const payload   = { event_type, actor: user.id, remarks, new_state };
  const hashInput = `${lastEvent?.event_hash ?? ""}|${event_type}|${user.id}|${now}|${JSON.stringify(payload)}`;
  const buf       = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(hashInput));
  const eventHash = Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");

  const { data, error } = await supabase.from("case_events").insert({
    complaint_id:    id,
    event_type,
    actor_id:        user.id,
    actor_role:      role,
    bureau,
    old_state:       old_state ?? null,
    new_state:       new_state ?? null,
    remarks,
    document_ids:    document_ids ?? [],
    event_at:        now,
    prev_event_hash: lastEvent?.event_hash ?? null,
    event_hash:      eventHash,
  }).select().single();

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  // Update last_action_at on complaint
  await supabase.from("complaints")
    .update({ last_action_at: now, updated_at: now })
    .eq("id", id);

  return NextResponse.json({ data }, { status: 201 });
}
