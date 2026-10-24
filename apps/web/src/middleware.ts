import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";

// Routes that never require auth
const PUBLIC_PATHS = ["/auth/login", "/auth/verify", "/auth/totp", "/auth/new-device", "/auth/error"];

// Portal prefix → allowed roles
const ROUTE_ROLE: Record<string, string[]> = {
  "/student":  ["student"],
  "/faculty":  ["faculty"],
  "/college":  ["college_management"],
  "/aicte":    ["pgrc_triage_officer", "bureau_officer", "regional_officer", "bureau_head", "competent_authority", "ombudsperson", "auditor", "system_admin"],
};

// Roles that MUST have MFA (aal2) to access their portal
const MFA_REQUIRED_ROLES = new Set([
  "college_management", "pgrc_triage_officer", "bureau_officer", "regional_officer",
  "bureau_head", "competent_authority", "ombudsperson", "auditor", "system_admin",
]);

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // 1. Always allow public auth routes and Next.js internals
  if (
    PUBLIC_PATHS.some((p) => pathname.startsWith(p)) ||
    pathname.startsWith("/_next") ||
    pathname.startsWith("/favicon") ||
    pathname === "/"
  ) {
    return refreshSession(request);
  }

  // 2. Determine which portal prefix this path falls under
  const portalPrefix = Object.keys(ROUTE_ROLE).find((prefix) =>
    pathname.startsWith(prefix)
  );
  if (!portalPrefix) {
    // Not a portal route — pass through (API routes handle their own auth)
    return refreshSession(request);
  }

  // 3. Build a Supabase client that can read/refresh the session cookie
  const response = NextResponse.next({ request });
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (updates) => {
          updates.forEach(({ name, value, options }) => {
            request.cookies.set(name, value);
            response.cookies.set(name, value, options);
          });
        },
      },
    }
  );

  // 4. Validate the Supabase session (also refreshes expiring tokens)
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    const loginUrl = new URL("/auth/login", request.url);
    loginUrl.searchParams.set("next", pathname);
    return NextResponse.redirect(loginUrl);
  }

  // 5. Load the user's active role assignment
  // CRITICAL: institution_id, bureau, region come from DB — never from the request body
  const { data: assignments, error: roleError } = await supabase
    .from("role_assignments")
    .select("role, institution_id, bureau, region")
    .eq("user_id", user.id)
    .is("revoked_at", null)
    .order("granted_at", { ascending: false })
    .limit(1);

  if (roleError || !assignments?.length) {
    // Authenticated but no role — show error page
    return NextResponse.redirect(new URL("/auth/error?reason=no_role", request.url));
  }

  const { role, institution_id, bureau, region } = assignments[0];
  const allowedRoles = ROUTE_ROLE[portalPrefix];

  // 6. Role-portal isolation — 403 if wrong portal for this role
  if (!allowedRoles.includes(role)) {
    return new NextResponse(
      JSON.stringify({ error: "Forbidden: your role cannot access this portal." }),
      { status: 403, headers: { "Content-Type": "application/json" } }
    );
  }

  // 7. MFA check — roles that require aal2 must complete TOTP before accessing portal
  if (MFA_REQUIRED_ROLES.has(role)) {
    const { data: assurance } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (assurance?.currentLevel !== "aal2") {
      const totpUrl = new URL("/auth/totp", request.url);
      totpUrl.searchParams.set("next", pathname);
      return NextResponse.redirect(totpUrl);
    }
  }

  // 8. Inject verified session claims into request headers for API route consumption
  // API routes read these headers — they NEVER trust request body for scope claims
  const forwardedRequest = NextResponse.next({ request });
  forwardedRequest.headers.set("x-user-id", user.id);
  forwardedRequest.headers.set("x-user-role", role);
  forwardedRequest.headers.set("x-user-institution", institution_id ?? "");
  forwardedRequest.headers.set("x-user-bureau", bureau ?? "");
  forwardedRequest.headers.set("x-user-region", region ?? "");

  // Copy refreshed cookies to the forwarded response
  response.cookies.getAll().forEach(({ name, value }) => {
    forwardedRequest.cookies.set(name, value);
  });

  return forwardedRequest;
}

// Helper: refresh session cookies without any auth check (for public routes)
function refreshSession(request: NextRequest) {
  const response = NextResponse.next({ request });
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (updates) => {
          updates.forEach(({ name, value, options }) => {
            request.cookies.set(name, value);
            response.cookies.set(name, value, options);
          });
        },
      },
    }
  );
  // Fire-and-forget session refresh (keeps JWT tokens alive)
  supabase.auth.getUser().catch(() => {});
  return response;
}

export const config = {
  matcher: [
    // Match all paths except static files and Next.js internals
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
