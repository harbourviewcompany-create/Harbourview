// lib/supabase/server.ts
// Server-side Supabase client. Uses validated public Supabase env vars and cookie-backed sessions.

import { createServerClient as _createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { getPublicSupabaseEnv, assertNoPublicSecretExposure } from "@/lib/security/env";

type SupabaseCookieToSet = {
  name: string;
  value: string;
  options?: Parameters<Awaited<ReturnType<typeof cookies>>["set"]>[2];
};

export async function createServerClient() {
  assertNoPublicSecretExposure();
  const env = getPublicSupabaseEnv();
  const cookieStore = await cookies();

  return _createServerClient(env.supabaseUrl, env.supabasePublishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet: SupabaseCookieToSet[]) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options);
          });
        } catch {
          // Server components cannot set cookies. Middleware refreshes sessions for request paths.
        }
      },
    },
  });
}
