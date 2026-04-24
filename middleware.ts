// middleware.ts
// Authenticates operator UI routes and attaches baseline security headers.
// Public paths: /login and /auth/*.
// Token-gated APIs must perform their own explicit token validation in route handlers.

import { createServerClient } from "@supabase/ssr";
import { NextRequest, NextResponse } from "next/server";
import { getPublicSupabaseEnv, assertNoPublicSecretExposure } from "@/lib/security/env";
import { attachSecurityHeaders, isSafeRelativePath } from "@/lib/security/http";

const PUBLIC_PATHS = ["/login", "/auth"];
const TOKEN_GATED_API_PATHS = ["/api/feed"];

type SupabaseCookieToSet = {
  name: string;
  value: string;
  options?: Parameters<NextResponse["cookies"]["set"]>[2];
};

function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

function isTokenGatedApiPath(pathname: string): boolean {
  return TOKEN_GATED_API_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

export async function middleware(request: NextRequest) {
  assertNoPublicSecretExposure();
  const env = getPublicSupabaseEnv();
  const { pathname } = request.nextUrl;

  if (isPublicPath(pathname) || isTokenGatedApiPath(pathname)) {
    return attachSecurityHeaders(NextResponse.next());
  }

  let response = NextResponse.next({
    request: { headers: request.headers },
  });

  const supabase = createServerClient(env.supabaseUrl, env.supabasePublishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: SupabaseCookieToSet[]) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = "/login";
    loginUrl.search = "";
    loginUrl.searchParams.set("next", isSafeRelativePath(pathname) ? pathname : "/app");
    return attachSecurityHeaders(NextResponse.redirect(loginUrl, { status: 303 }));
  }

  return attachSecurityHeaders(response);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|robots.txt|sitemap.xml).*)"],
};
