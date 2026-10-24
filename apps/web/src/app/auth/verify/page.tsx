import VerifyForm from "@/components/auth/verify-form";

export default async function VerifyPage({ searchParams }: { searchParams: Promise<{ email?: string; code?: string }> }) {
  const { email = "", code = "" } = await searchParams;
  return <main className="shell"><VerifyForm email={email} initialCode={code} /></main>;
}
