// lib/audit.ts
// Harbourview Production Spine — audit event writer
// All state transitions must call writeAuditEvent. This is the only approved write path.

import { createServerClient } from "@/lib/supabase/server";

export type AuditEventInput = {
  entity_type: string;
  entity_id: string;
  action_type:
    | "create"
    | "update"
    | "submit_for_review"
    | "approve"
    | "reject"
    | "return_for_revision"
    | "publish"
    | "revoke"
    | "archive"
    | "restore"
    | "merge"
    | "membership_change";
  performed_by_profile_id: string;
  from_status?: string;
  to_status?: string;
  change_summary?: string;
  diff_json?: Record<string, unknown>;
  workspace_id?: string;
};

/**
 * Writes an audit event. Never throws — audit failures are logged
 * but do not roll back the primary action. If you need transactional
 * audit writing, use the write_audit_event() Postgres function directly
 * inside a DB transaction.
 */
export async function writeAuditEvent(input: AuditEventInput): Promise<void> {
  try {
    const supabase = await createServerClient();

    const { error } = await supabase.from("audit_events").insert({
      entity_type: input.entity_type,
      entity_id: input.entity_id,
      action_type: input.action_type,
      performed_by_profile_id: input.performed_by_profile_id,
      from_status: input.from_status ?? null,
      to_status: input.to_status ?? null,
      change_summary: input.change_summary ?? null,
      diff_json: input.diff_json ?? null,
      workspace_id: input.workspace_id ?? null,
    });

    if (error) {
      console.error(
        `[audit] Failed to write audit event for ${input.entity_type}:${input.entity_id}`,
        error.message
      );
    }
  } catch (err) {
    console.error("[audit] Unexpected error writing audit event:", err);
  }
}
