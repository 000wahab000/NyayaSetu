import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { auditLog } from "@/lib/audit";
import { getAppSession } from "@/lib/auth/session";
import { getVisibleCaseEvents, getVisibleComplaint } from "@/lib/db/queries";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params; if (!z.string().uuid().safeParse(id).success) return NextResponse.json({ error: "Not found." }, { status: 404 });
  const supabase = await createClient(); const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthenticated" }, { status: 401 });
  const appSession = await getAppSession(user);
  if (!appSession) return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  const { data, error } = await getVisibleComplaint(supabase, id);
  if (error || !data) return NextResponse.json({ error: "Not found." }, { status: 404 });
  if (data.is_confidential || data.involves_management) await auditLog({ actor_id: user.id, action: "case.sensitive_viewed", resource_type: "complaint", resource_id: data.id });
  const { data: events } = await getVisibleCaseEvents(supabase, id);
  const responseData = appSession.role === "student" ? (({ assigned_officer: _officer, assigned_bureau: _bureau, ...safe }) => safe)(data) : data;
  return NextResponse.json({ data: { ...responseData, events: events ?? [] } }, { headers: { "Cache-Control": "private, no-store" } });
}
