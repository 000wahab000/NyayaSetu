import LogoutButton from "@/components/auth/logout-button";
import type { AppSession } from "@/lib/auth/session";

const TITLES: Record<string, string> = { student: "Student portal", faculty: "Faculty portal", college_management: "College management portal", aicte: "AICTE operations portal" };
export default function PortalHome({ portal, session }: { portal: keyof typeof TITLES; session: AppSession }) {
  return <main className="portal"><header><div><div className="brand">NyayaSetu · Foundation</div><h1>{TITLES[portal]}</h1></div><LogoutButton /></header>
    <section className="card" style={{ marginTop: 28 }}><h2>Access is configured</h2><p className="muted">Phase 1 provides authenticated, role-scoped access. Portal workflows will be added in later phases.</p><p><strong>Role:</strong> {session.role}</p>{session.institutionId && <p><strong>Institution scope:</strong> {session.institutionId}</p>}{session.bureau && <p><strong>Bureau:</strong> {session.bureau}</p>}{session.region && <p><strong>Region:</strong> {session.region}</p>}<p><a href="/auth/new-device">Manage signed-in devices</a></p></section>
  </main>;
}
