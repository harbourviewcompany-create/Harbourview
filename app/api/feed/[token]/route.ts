// app/api/feed/[token]/route.ts
// Harbourview Production Spine — JSON feed endpoint
// ADR-001 D4: client delivery mechanism. No client UI. Clients consume this endpoint.
// Authentication: scoped api_token from publish_events table.
// Internal notes are NEVER included in the response.
//
// REVOCATION MODEL (OI-7 fix):
//   Revocation is an append-only INSERT row (status='revoked', revokes_event_id=original.id).
//   The original publish_events row is immutable — its status field never changes.
//   Detection: query for a revocation row WHERE revokes_event_id = publishEvent.id.
//   Do NOT check publishEvent.status — it will always read 'completed'.

import { NextRequest, NextResponse } from "next/server";
import { createServiceClient } from "@/lib/supabase/service";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ token: string }> }
) {
  const { token } = await params;

  if (!token || typeof token !== "string" || token.length < 10) {
    return NextResponse.json(
      { error: "Invalid or missing feed token" },
      { status: 400 }
    );
  }

  // Use service client — feed tokens bypass RLS by design,
  // but we gate on token validity and revocation status.
  const supabase = createServiceClient();

  const { data: publishEvent, error } = await supabase
    .from("publish_events")
    .select("id, snapshot_json, dossier_id, workspace_id, created_at")
    .eq("api_token", token)
    .eq("status", "completed")
    .maybeSingle();

  if (error) {
    console.error("[feed] DB error:", error.message);
    return NextResponse.json(
      { error: "Feed unavailable" },
      { status: 503 }
    );
  }

  if (!publishEvent) {
    // Return 404 — do not distinguish between invalid token and not-yet-published
    return NextResponse.json(
      { error: "Feed not found" },
      { status: 404 }
    );
  }

  // Revocation check: look for an append-only revocation row referencing this event.
  // The original row is immutable — revocation is always a new INSERT.
  const { data: revocationRow, error: revErr } = await supabase
    .from("publish_events")
    .select("id")
    .eq("revokes_event_id", publishEvent.id)
    .eq("status", "revoked")
    .maybeSingle();

  if (revErr) {
    console.error("[feed] revocation check error:", revErr.message);
    return NextResponse.json(
      { error: "Feed unavailable" },
      { status: 503 }
    );
  }

  if (revocationRow) {
    return NextResponse.json(
      {
        error: "This feed has been revoked. Contact your Harbourview representative.",
        revoked: true,
      },
      { status: 410 } // 410 Gone — semantically correct for revoked content
    );
  }

  const snapshot = publishEvent.snapshot_json as Record<string, unknown>;

  // Final safety check: strip any internal_notes fields that may have
  // been accidentally included in the snapshot at publish time.
  const sanitized = sanitizeSnapshot(snapshot);

  return NextResponse.json(
    {
      meta: {
        feed_id: publishEvent.id,
        published_at: (sanitized.published_at as string) ?? publishEvent.created_at,
        effective_at: sanitized.effective_at ?? null,
        version_number: sanitized.version_number ?? 1,
      },
      dossier: sanitized,
    },
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        // Prevent caching of intelligence feeds
        "Cache-Control": "no-store, no-cache, must-revalidate",
        "X-Harbourview-Feed": "v1",
      },
    }
  );
}

// Recursively strip internal_notes and analyst_notes from any level of the snapshot
function sanitizeSnapshot(obj: unknown): Record<string, unknown> {
  if (typeof obj !== "object" || obj === null) return obj as any;

  if (Array.isArray(obj)) {
    return obj.map(sanitizeSnapshot) as unknown as Record<string, unknown>;
  }

  const record = obj as Record<string, unknown>;
  const sanitized: Record<string, unknown> = {};

  const BLOCKED_FIELDS = new Set([
    "internal_notes",
    "analyst_notes",
    "reviewer_notes",
    "item_notes",      // dossier_items editorial note — never client-visible (test G9)
  ]);

  for (const [key, value] of Object.entries(record)) {
    if (BLOCKED_FIELDS.has(key)) continue;
    sanitized[key] =
      typeof value === "object" && value !== null
        ? sanitizeSnapshot(value)
        : value;
  }

  return sanitized;
}
