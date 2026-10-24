"use client";
import { useState } from "react";
import { useSearchParams } from "next/navigation";

export default function LoginForm() {
  const [email, setEmail] = useState(""); const [busy, setBusy] = useState(false); const [error, setError] = useState("");
  const params = useSearchParams();
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError("");
    const response = await fetch("/api/auth/otp", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email }) });
    const result = await response.json(); setBusy(false);
    if (!response.ok) return setError(result.error ?? "Could not send code.");
    window.location.href = `/auth/verify?email=${encodeURIComponent(email)}`;
  }
  return <section className="card"><div className="brand">NyayaSetu · CaseBridge AI</div><h1>Sign in securely</h1><p className="muted">We’ll email a one-time code to your registered account. Access is granted only to accounts provisioned by an administrator.</p>
    {params.get("error") === "account_not_provisioned" && <p className="error">This account has no active portal role. Contact your administrator.</p>}
    <form onSubmit={submit}><label htmlFor="email">Registered email</label><input id="email" type="email" autoComplete="email" required maxLength={254} value={email} onChange={(e) => setEmail(e.target.value)} /><button disabled={busy}>{busy ? "Sending…" : "Send one-time code"}</button></form>
    {error && <p role="alert" className="error">{error}</p>}
  </section>;
}
