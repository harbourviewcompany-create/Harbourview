import { NextResponse } from "next/server";
import { createServerClient } from "@/lib/supabase/server";
import { getPublicSupabaseEnv } from "@/lib/security/env";
import { attachSecurityHeaders, jsonError } from "@/lib/security/http";
import { requireRole } from "@/lib/auth";

export async function GET() {
  const startedAt = Date.now();

  try {
    const env = getPublicSupabaseEnv();
    const supabase = await createServerClient();
    await requireRole(supabase, ["admin"]);

    const { error } = await supabase.from("profiles").select("id", { head: true, count: "exact" }).limit(1);
    if (error) {
      return jsonError("Database connectivity check failed", 503);
    }

    return attachSecurityHeaders(
      NextResponse.json(
        {
          ok: true,
          service: "harbourview-web",
          environment: env.isProduction ? "production" : "non-production",
          latency_ms: Date.now() - startedAt,
        },
        {
          headers: {
            "Cache-Control": "no-store",
          },
        }
      )
    );
  } catch {
    return jsonError("Health check unavailable", 503);
  }
}
