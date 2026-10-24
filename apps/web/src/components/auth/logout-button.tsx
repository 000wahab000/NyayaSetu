"use client";
export default function LogoutButton() {
  async function logout() { await fetch("/api/auth/logout", { method: "POST" }); window.location.href = "/auth/login"; }
  return <button onClick={logout}>Sign out</button>;
}
