import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { auditLog } from "@/lib/audit";

const Body = z.object({ email: z.string().email().max(254) }).strict();
export async function POST(request: Request) {
  const parsed = Body.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Enter a valid email address." }, { status: 400 });

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithOtp({ email: parsed.data.email, options: { shouldCreateUser: false } });

  // Generic response: never reveal whether the email is provisioned or whether delivery failed.
  if (error) {
    await auditLog({ action: "auth.otp_send_failed", resource_type: "auth", reason: error.code ?? "send_failure" });
    return NextResponse.json({ sent: true });
  }

  await auditLog({ action: "auth.otp_requested", resource_type: "auth", reason: null });
  return NextResponse.json({ sent: true });
}
