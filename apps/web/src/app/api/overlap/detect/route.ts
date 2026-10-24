// POST /api/overlap/detect
// Scans complaints and generates Alert 1 (cross-bureau) and Alert 2 (related cases).
// Idempotent — safe to call multiple times; deduplicates by institution+complaint_ids.

import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

const TERMINAL = ["closed", "appeal_decided", "out_of_scope"];
const ALERT1_MIN_BUREAUS  = 2;    // at least 2 distinct bureaus at same institution
const ALERT2_MIN_SCORE    = 0.60; // minimum weighted score to trigger Alert 2
const ALERT2_DATE_WINDOW  = 30;   // days between filings to get date proximity score

export async function POST(req: NextRequest) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  // Only officers can trigger detection
  const role = req.headers.get("x-user-role") ?? "";
  const allowed = ["pgrc_triage_officer","bureau_officer","bureau_head","system_admin"];
  if (!allowed.includes(role))
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });

  // Load all non-terminal complaints with institution and bureau info
  const { data: complaints, error } = await supabase
    .from("complaints")
    .select("id, institution_id, category, assigned_bureau, receipt_date, coordination_status")
    .not("status", "in", `(${TERMINAL.map(s => `"${s}"`).join(",")})`)
    .not("assigned_bureau", "is", null);

  if (error || !complaints) return NextResponse.json({ error: "Failed to load complaints" }, { status: 500 });

  // Load existing open alerts to avoid duplicates
  const { data: existingAlerts } = await supabase
    .from("overlap_alerts")
    .select("id, institution_id, complaint_ids, alert_type, status")
    .eq("status", "open");

  const existingKeys = new Set(
    (existingAlerts ?? []).map(a =>
      `${a.alert_type}:${a.institution_id}:${[...a.complaint_ids].sort().join(",")}`
    )
  );

  // Group by institution
  const byInstitution: Record<string, typeof complaints> = {};
  complaints.forEach(c => {
    if (!byInstitution[c.institution_id]) byInstitution[c.institution_id] = [];
    byInstitution[c.institution_id].push(c);
  });

  const newAlerts: object[] = [];

  for (const [institution_id, cases] of Object.entries(byInstitution)) {
    if (cases.length < 2) continue;

    // ── Alert 1: Cross-bureau coordination ──────────────────────────────
    const bureaus = [...new Set(cases.map(c => c.assigned_bureau).filter(Boolean))];
    if (bureaus.length >= ALERT1_MIN_BUREAUS) {
      const ids = cases.map(c => c.id).sort();
      const key = `coordination:${institution_id}:${ids.join(",")}`;
      if (!existingKeys.has(key)) {
        newAlerts.push({
          institution_id,
          alert_type: "coordination",
          status: "open",
          complaint_ids: ids,
          match_factors: {
            bureaus,
            bureau_count: bureaus.length,
            case_count:   cases.length,
          },
        });
        existingKeys.add(key);
      }
    }

    // ── Alert 2: Potentially related cases ──────────────────────────────
    for (let i = 0; i < cases.length; i++) {
      for (let j = i + 1; j < cases.length; j++) {
        const a = cases[i];
        const b = cases[j];

        // Skip pairs already linked or dismissed
        if (a.coordination_status === "dismissed" || b.coordination_status === "dismissed") continue;
        if (a.coordination_status === "linked"    || b.coordination_status === "linked")    continue;

        let score = 0;
        const factors: Record<string, number | boolean | string> = {};

        // Factor 1: same category (0.4)
        if (a.category === b.category) {
          score += 0.4;
          factors.same_category = true;
        }

        // Factor 2: filing date proximity within 30 days (0.3)
        const daysDiff = Math.abs(
          new Date(a.receipt_date).getTime() - new Date(b.receipt_date).getTime()
        ) / 86_400_000;
        if (daysDiff <= ALERT2_DATE_WINDOW) {
          const proximity = Math.round((1 - daysDiff / ALERT2_DATE_WINDOW) * 10) / 10;
          score += 0.3 * proximity;
          factors.date_proximity = proximity;
          factors.days_apart = Math.round(daysDiff);
        }

        // Factor 3: different bureaus (0.2) — cross-bureau makes it more notable
        if (a.assigned_bureau !== b.assigned_bureau) {
          score += 0.2;
          factors.different_bureaus = true;
        }

        // Factor 4: pg_trgm text similarity — fetched via RPC (0.1)
        // We skip this expensive call if score already below threshold without it
        let textSim = 0;
        if (score + 0.1 >= ALERT2_MIN_SCORE) {
          const { data: simResult } = await supabase.rpc("text_similarity", {
            complaint_a: a.id,
            complaint_b: b.id,
          }).maybeSingle();
          if (typeof simResult === "number") {
            textSim = Math.round(simResult * 100) / 100;
            score += 0.1 * textSim;
            factors.text_similarity = textSim;
          }
        }

        factors.match_strength = Math.round(score * 100) / 100;

        if (score >= ALERT2_MIN_SCORE) {
          const ids = [a.id, b.id].sort();
          const key = `related:${institution_id}:${ids.join(",")}`;
          if (!existingKeys.has(key)) {
            newAlerts.push({
              institution_id,
              alert_type: "related",
              status: "open",
              complaint_ids: ids,
              match_factors: factors,
            });
            existingKeys.add(key);
          }
        }
      }
    }
  }

  if (newAlerts.length > 0) {
    const { error: insertError } = await supabase
      .from("overlap_alerts")
      .insert(newAlerts);
    if (insertError) return NextResponse.json({ error: insertError.message }, { status: 500 });

    // Mark involved complaints as possible_overlap
    for (const alert of newAlerts as Array<{ complaint_ids: string[] }>) {
      await supabase
        .from("complaints")
        .update({ coordination_status: "possible_overlap" })
        .in("id", alert.complaint_ids)
        .eq("coordination_status", "no_overlap");
    }
  }

  return NextResponse.json({
    generated: newAlerts.length,
    scanned:   complaints.length,
    message:   `Detection complete. ${newAlerts.length} new alert(s) created.`,
  });
}
