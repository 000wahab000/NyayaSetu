// API: GET  /api/complaints/[id]       — full case detail
//      POST /api/complaints/[id]/transition — state machine transition
//      POST /api/complaints/[id]/assign     — assign bureau + officer
//      POST /api/complaints/[id]/transfer   — transfer to another bureau

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { isValidTransition, canRoleTransition, type LifecycleStatus } from "@/lib/state-machine";
import { z } from "zod";

export async function GET(_req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const { data, error } = await supabase
    .from("complaints")
    .select(`
      *, 
      institutions(id, name, aicte_permanent_id, region, type, status),
      users!submitted_by(display_name, email),
      users!assigned_officer(display_name, email)
    `)
    .eq("id", id)
    .single();

  if (error || !data) return NextResponse.json({ error: "Not found" }, { status: 404 });
  return NextResponse.json({ data });
}
