"use client";
import { useState } from "react";

export default function VerifyForm({ email, initialCode = "" }: { email: string; initialCode?: string }) {
  const [token, setToken] = useState(initialCode); const [busy, setBusy] = useState(false); const [error, setError] = useState("");
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError("");
    const response = await fetch("/api/auth/verify", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, token }) });
    const result = await response.json(); setBusy(false);
    if (!response.ok) return setError(result.error ?? "Could not verify code.");
    window.location.href = result.redirectTo;
  }
  return <section className="card"><div className="brand">NyayaSetu · Sign in</div><h1>Enter your email code</h1><p className="muted">Code sent to {email || "your registered email"}.</p>
    {initialCode && <p className="success" style={{ background: "#e6f4ea", color: "#137333", padding: "0.5rem 0.75rem", borderRadius: "6px", fontSize: "0.875rem", marginBottom: "1rem" }}>✓ Generated verification code: <strong>{initialCode}</strong></p>}
    <form onSubmit={submit}><label htmlFor="token">One-time code</label><input id="token" inputMode="numeric" autoComplete="one-time-code" minLength={6} maxLength={10} required value={token} onChange={(e) => setToken(e.target.value.replace(/\s/g, ""))} /><button disabled={busy}>{busy ? "Checking…" : "Verify and continue"}</button></form>
    {error && <p role="alert" className="error">{error}</p>}
  </section>;
}
