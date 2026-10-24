import LogoutButton from "@/components/auth/logout-button";
import type { AppSession } from "@/lib/auth/session";
const TITLES={student:"Student portal",faculty:"Faculty portal",college_management:"College management portal",aicte:"AICTE operations portal"};
export default function PortalHome({portal,session}:{portal:keyof typeof TITLES;session:AppSession}){return <main className="portal"><header><div><div className="brand">NyayaSetu</div><h1>{TITLES[portal]}</h1></div><LogoutButton/></header><section className="card" style={{marginTop:28}}><h2>Portal</h2><p className="muted">Your authenticated role is {session.role}.</p><p><a href="/auth/new-device">Manage signed-in devices</a></p></section></main>}
