import { cookies } from "next/headers";
import VerifyForm from "@/components/auth/verify-form";
import { DEMO_CODE_COOKIE } from "@/lib/auth/demo";

export default async function VerifyPage({ searchParams }: { searchParams: Promise<{ email?: string }> }) {
  const { email = "" } = await searchParams;
  // Set only outside production for demo accounts (see /api/auth/otp); expires after two minutes.
  const demoCode = process.env.NODE_ENV !== "production" ? (await cookies()).get(DEMO_CODE_COOKIE)?.value ?? "" : "";
  return <main className="shell"><VerifyForm email={email} initialCode={demoCode} /></main>;
}
