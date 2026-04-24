// lib/supabase/service.ts
// Service role client. Server-only. Bypasses RLS and must never be imported by client components.

import { createClient } from "@supabase/supabase-js";
import { getServiceRoleEnv, assertNoPublicSecretExposure } from "@/lib/security/env";

export function createServiceClient() {
  assertNoPublicSecretExposure();
  const env = getServiceRoleEnv();

  return createClient(env.supabaseUrl, env.serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
