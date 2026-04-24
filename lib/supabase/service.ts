// lib/supabase/service.ts
// Service role client — bypasses RLS. Use ONLY in:
//   - the JSON feed route handler (token-gated, no user session)
//   - background jobs with no user context
// Never use in server actions that have a user session — use createServerClient instead.

import { createClient } from "@supabase/supabase-js";

export function createServiceClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !key) {
    throw new Error(
      "Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. " +
        "Service client cannot be initialized."
    );
  }

  return createClient(url, key, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
