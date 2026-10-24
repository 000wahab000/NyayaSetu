import "server-only";
import { createClient } from "@/lib/supabase/server";
import { getAppSession } from "@/lib/auth/session";

export async function getApiSession() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const session = user ? await getAppSession(user) : null;
  return session ? { supabase, session } : null;
}
