// API: GET /api/complaints — case table with 8 PS filter keys
//      POST /api/complaints — create new case (PGRC intake)

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { z } from "zod";

const CreateComplaintSchema = z.object({
  institution_id:    z.string().uuid(),
  category:          z.enum(["financial", "ragging", "academic", "infrastructure", "other"]),
  secondary_category: z.string().max(80).optional(),
  description_text:  z.string().min(10).max(10000),
  description_language: z.string().default("en"),
  is_confidential:   z.boolean().default(false),
  involves_management: z.boolean().default(false),
  urgency_status:    z.enum(["untriaged", "urgent"]).default("untriaged"),
});

export async function GET(req: NextRequest) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { searchParams } = req.nextUrl;
  const page   = Math.max(1, parseInt(searchParams.get("page") ?? "1"));
  const limit  = Math.min(100, parseInt(searchParams.get("limit") ?? "25"));
  const offset = (page - 1) * limit;

  let query = supabase
    .from("complaints")
    .select(`
      id, case_id, institution_id, category, status,
      verification_status, coordination_status, deadline_status,
      urgency_status, assigned_bureau, last_action_at,
      expected_disposal_at, receipt_date, is_confidential,
      involves_management, is_demo, created_at,
      institutions(name, region, aicte_permanent_id),
      users!assigned_officer(display_name)
    `, { count: "exact" });

  // 8 PS filter keys
  const institution_name = searchParams.get("institution_name");
  const aicte_id         = searchParams.get("aicte_id");
  const case_id          = searchParams.get("case_id");
  const bureau           = searchParams.get("bureau");
  const region           = searchParams.get("region");
  const category         = searchParams.get("category");
  const status           = searchParams.get("status");
  const date_from        = searchParams.get("date_from");
  const date_to          = searchParams.get("date_to");

  if (case_id)   query = query.ilike("case_id", `%${case_id}%`);
  if (bureau)    query = query.eq("assigned_bureau", bureau);
  if (category)  query = query.eq("category", category);
  if (status)    query = query.eq("status", status);
  if (date_from) query = query.gte("receipt_date", date_from);
  if (date_to)   query = query.lte("receipt_date", date_to);

  // Institution filters (via join)
  if (institution_name)
    query = query.ilike("institutions.name", `%${institution_name}%`);
  if (aicte_id)
    query = query.eq("institutions.aicte_permanent_id", aicte_id);
  if (region)
    query = query.eq("institutions.region", region);

  const { data, count, error } = await query
    .order("receipt_date", { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  return NextResponse.json({ data, total: count ?? 0, page, limit });
}

export async function POST(req: NextRequest) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  // Only PGRC triage officers and students can create complaints
  const role = req.headers.get("x-user-role");
  if (!role || !["pgrc_triage_officer", "student"].includes(role)) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const body = await req.json();
  const parsed = CreateComplaintSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const input = parsed.data;

  // Generate case_id using DB function
  const { data: caseIdRow } = await supabase.rpc("next_case_id");
  const case_id = caseIdRow as string;

  const { data: complaint, error } = await supabase
    .from("complaints")
    .insert({
      case_id,
      institution_id:       input.institution_id,
      submitted_by:         user.id,
      category:             input.category,
      secondary_category:   input.secondary_category ?? null,
      description_text:     input.description_text,
      description_language: input.description_language,
      is_confidential:      input.is_confidential,
      involves_management:  input.involves_management,
      urgency_status:       input.urgency_status,
      status:               "submitted",
      verification_status:  "pending",
      coordination_status:  "no_overlap",
      deadline_status:      "on_track",
      appeal_status:        "not_applicable",
      is_demo:              false,
    })
    .select()
    .single();

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  // Append initial case_submitted event
  const prevEvent = null;
  const eventPayload = { case_id, status: "submitted", actor: user.id };
  const eventHash = await hashEvent(null, "case_submitted", user.id, new Date().toISOString(), eventPayload);

  await supabase.from("case_events").insert({
    complaint_id: complaint.id,
    event_type:   "case_submitted",
    actor_id:     user.id,
    actor_role:   role,
    new_state:    { status: "submitted" },
    prev_event_hash: null,
    event_hash:   eventHash,
    event_at:     new Date().toISOString(),
  });

  // Add complainant as participant
  await supabase.from("participants").insert({
    complaint_id: complaint.id,
    user_id:      user.id,
    role:         "complainant",
    access_scope: "redacted_summary",
  });

  // Fire-and-forget overlap detection — does not block the response
  fetch(`${req.nextUrl.origin}/api/overlap/detect`, {
    method: "POST",
    headers: {
      "x-user-role":   role,
      "x-user-bureau": req.headers.get("x-user-bureau") ?? "",
      "Cookie":        req.headers.get("cookie") ?? "",
    },
  }).catch(() => { /* best-effort */ });

  return NextResponse.json({ complaint }, { status: 201 });
}

async function hashEvent(prevHash: string | null, eventType: string, actorId: string, eventAt: string, payload: unknown): Promise<string> {
  const input = `${prevHash ?? ""}|${eventType}|${actorId}|${eventAt}|${JSON.stringify(payload)}`;
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}
