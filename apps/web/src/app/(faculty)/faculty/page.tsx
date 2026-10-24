import { createClient } from "@/lib/supabase/server";
import { getAppSession } from "@/lib/auth/session";
import PortalHome from "@/components/portal-home";

export default async function FacultyPortal() { const supabase = await createClient(); const { data: { user } } = await supabase.auth.getUser(); const session = user ? await getAppSession(user) : null; if (!session) return null; return <PortalHome portal="faculty" session={session} />; }
