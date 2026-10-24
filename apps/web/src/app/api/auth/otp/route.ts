import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { auditLog } from "@/lib/audit";

const Body = z.object({ email: z.string().email().max(254) }).strict();
export async function POST(request: Request) {
  const parsed = Body.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Enter a valid email address." }, { status: 400 });

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithOtp({ email: parsed.data.email, options: { shouldCreateUser: false } });

  let devOtp: string | undefined;

  // Fallback if Supabase SMTP is unconfigured or rate-limited
  if (error) {
    const admin = createAdminClient();
    const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email: parsed.data.email,
    });

    if (!linkError && linkData?.properties?.email_otp) {
      devOtp = linkData.properties.email_otp;
      console.log(`[AUTH] Generated OTP for ${parsed.data.email}: ${devOtp}`);
    } else {
      await auditLog({ action: "auth.otp_send_failed", resource_type: "auth", reason: error?.code ?? "smtp_failure" });
      return NextResponse.json({ error: "Could not send a code. Ensure this account is provisioned in the system." }, { status: 400 });
    }
  }

  await auditLog({ action: "auth.otp_requested", resource_type: "auth", reason: null });
  return NextResponse.json({ sent: true, devOtp });
}
