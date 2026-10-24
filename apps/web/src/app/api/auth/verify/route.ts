import { NextResponse } from "next/server";
import { cookies, headers } from "next/headers";
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getAppSession } from "@/lib/auth/session";
import { destinationFor } from "@/lib/auth/redirect";
import { auditLog } from "@/lib/audit";

const Body = z.object({ email: z.string().email().max(254), token: z.string().min(6).max(10).regex(/^\d+$/) }).strict();
export async function POST(request: Request) {
  const parsed = Body.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Invalid email or code." }, { status: 400 });
  const supabase = await createClient();
  const { data, error } = await supabase.auth.verifyOtp({ email: parsed.data.email, token: parsed.data.token, type: "email" });
  if (error || !data.user) {
    await auditLog({ action: "auth.login_failed", resource_type: "auth", reason: error?.code ?? "invalid_otp" });
    return NextResponse.json({ error: "The code is invalid or expired." }, { status: 401 });
  }
  const session = await getAppSession(data.user);
  if (!session) {
    await supabase.auth.signOut();
    await auditLog({ action: "auth.login_rejected_unprovisioned", resource_type: "auth", actor_id: data.user.id });
    return NextResponse.json({ error: "This account has no active portal role. Contact your administrator." }, { status: 403 });
  }
  const sessionId = randomUUID(); const headerStore = await headers(); const admin = createAdminClient();
  const { error: sessionError } = await admin.from("user_sessions").insert({ user_id: data.user.id, auth_session_id: sessionId, user_agent: headerStore.get("user-agent") });
  if (sessionError) {
    await supabase.auth.signOut();
    await auditLog({ action: "auth.session_record_failed", resource_type: "auth", actor_id: data.user.id, reason: sessionError.code });
    return NextResponse.json({ error: "Could not securely register this session. Please retry." }, { status: 500 });
  }
  await auditLog({ action: "auth.login_succeeded", resource_type: "auth", actor_id: data.user.id, session_id: sessionId });
  const cookieStore = await cookies();
  cookieStore.set("nyaya_session", sessionId, { httpOnly: true, secure: process.env.NODE_ENV === "production", sameSite: "lax", path: "/", maxAge: 60 * 60 * 8 });
  const redirectTo = destinationFor(session);
  return NextResponse.json({ authenticated: true, redirectTo });
}
