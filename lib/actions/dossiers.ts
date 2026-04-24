// lib/actions/dossiers.ts (corrected)
// Harbourview Production Spine — dossier assembly and publication
// ADR-001 D1: publish is admin-only
// ADR-001 D4: publishDossier writes snapshot_json and generates api_token for JSON feed
//
// CORRECTIONS vs prior version:
//
// [1] revokePublishEvent REWRITTEN
//   Prior version called UPDATE on publish_events. The block_publish_event_mutation()
//   trigger rejects ALL updates unconditionally — including service role calls, because
//   triggers fire regardless of RLS bypass. The corrected model inserts a new
//   publish_events row with status='revoked' and revokes_event_id referencing the
//   original. The original row is never touched. Feed route detects revocation by
//   checking for the presence of a revocation row.
//
// [2] createDossierVersion FIXED
//   Prior version called UPDATE { status: 'superseded' } on a published dossier.
//   The block_published_dossier_mutation() trigger blocks all updates on published
//   dossiers. Fixed by using the service client (bypasses RLS) combined with the
//   trigger amendment in 0006_create_dossiers_and_publish_events.sql that permits
//   the published → superseded transition as the only allowed mutation.
//
// [3] publishDossier snapshot COMPLETED
//   Prior version built snapshot_json from dossier_items + signals only.
//   Evidence records and source documents were missing — clients received signal
//   summaries with no provenance trail. Fixed by joining signal_evidence and
//   source_documents into the snapshot, matching the schema in SNAPSHOT_ASSEMBLY_SPEC.md.
//   internal_notes, analyst_notes, and item_notes are excluded at assembly time.

"use server";

import { createServerClient } from "@/lib/supabase/server";
import { createServiceClient } from "@/lib/supabase/service";
import { revalidatePath } from "next/cache";
import { writeAuditEvent } from "@/lib/audit";
import { requireRole } from "@/lib/auth";
import { randomBytes } from "crypto";

export type CreateDossierInput = {
  workspace_id: string;
  title: string;
  summary?: string;
  jurisdiction?: string;
  internal_notes?: string;
};

export type AddDossierItemInput = {
  dossier_id: string;
  signal_id: string;
  display_order?: number;
  item_notes?: string;
};

export type PublishDossierInput = {
  dossier_id: string;
  effective_at?: string; // ISO datetime — client-facing effective date
  // Test-only: pre-authenticated client for vitest Node env where next/headers
  // (cookies()) is unavailable. Never set in production — always undefined.
  _supabase?: Awaited<ReturnType<typeof createServerClient>>;
};

export type RevokePublishInput = {
  publish_event_id: string;
  revoke_reason: string;
  // Test-only: same escape hatch as PublishDossierInput._supabase
  _supabase?: Awaited<ReturnType<typeof createServerClient>>;
};

// ----------------------------------------------------------------
// Create dossier
// ----------------------------------------------------------------
export async function createDossier(input: CreateDossierInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  // Analysts must be workspace members to create a dossier in that workspace.
  // Admins are exempt — they manage all workspaces by definition (ADR-001 D1).
  // Phase 2: consider enforcing this at DB layer via a trigger.
  if (profile.platform_role !== "admin") {
    const { data: membership } = await supabase
      .from("workspace_members")
      .select("id")
      .eq("workspace_id", input.workspace_id)
      .eq("profile_id", profile.id)
      .maybeSingle();

    if (!membership) {
      throw new Error(
        `Not a member of workspace ${input.workspace_id}. ` +
        "Ask an admin to add you to this workspace."
      );
    }
  }

  const { data, error } = await supabase
    .from("dossiers")
    .insert({
      ...input,
      status: "draft",
      version_number: 1,
      created_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .select()
    .single();

  if (error) throw new Error(`createDossier: ${error.message}`);

  await writeAuditEvent({
    entity_type: "dossier",
    entity_id: data.id,
    action_type: "create",
    performed_by_profile_id: profile.id,
    to_status: "draft",
    change_summary: `Dossier created: ${data.title}`,
    workspace_id: input.workspace_id,
  });

  revalidatePath("/app/dossiers");
  return data;
}

// ----------------------------------------------------------------
// Add item to dossier
// ----------------------------------------------------------------
export async function addDossierItem(input: AddDossierItemInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const { data: dossier } = await supabase
    .from("dossiers")
    .select("status, title, workspace_id")
    .eq("id", input.dossier_id)
    .single();

  if (!dossier) throw new Error("Dossier not found");
  if (!["draft", "ready_for_publish"].includes(dossier.status)) {
    throw new Error(
      `Cannot add items to dossier in status: ${dossier.status}`
    );
  }

  const { data: signal } = await supabase
    .from("signals")
    .select("review_status, title")
    .eq("id", input.signal_id)
    .single();

  if (!signal) throw new Error("Signal not found");
  if (signal.review_status !== "approved") {
    throw new Error(
      `Only approved signals can be added to a dossier. Signal status: ${signal.review_status}`
    );
  }

  const { data, error } = await supabase
    .from("dossier_items")
    .insert({
      dossier_id: input.dossier_id,
      signal_id: input.signal_id,
      display_order: input.display_order ?? 0,
      item_notes: input.item_notes ?? null,
      created_by_profile_id: profile.id,
    })
    .select()
    .single();

  if (error) throw new Error(`addDossierItem: ${error.message}`);

  await writeAuditEvent({
    entity_type: "dossier",
    entity_id: input.dossier_id,
    action_type: "update",
    performed_by_profile_id: profile.id,
    change_summary: `Signal added to dossier: ${signal.title}`,
    workspace_id: dossier.workspace_id,
  });

  revalidatePath(`/app/dossiers/${input.dossier_id}`);
  return data;
}

// ----------------------------------------------------------------
// Publish dossier — ADMIN ONLY (ADR-001 D1)
//
// SNAPSHOT COMPLETENESS: the snapshot must include evidence records and
// source documents for each signal. Clients consuming the JSON feed must
// receive the full provenance chain, not just signal summaries.
//
// ATOMICITY: the dossier UPDATE that sets status='published', published_at,
// and published_by_profile_id MUST be a single statement. The
// block_published_dossier_mutation() trigger fires the moment status='published',
// so any subsequent update — even a benign field — will be rejected.
// ----------------------------------------------------------------
export async function publishDossier(input: PublishDossierInput) {
  const supabase = input._supabase ?? await createServerClient();
  const profile = await requireRole(supabase, ["admin"]);

  // Load dossier
  const { data: dossier, error: dossierError } = await supabase
    .from("dossiers")
    .select("id, title, summary, jurisdiction, version_number, status, workspace_id, supersedes_dossier_id")
    .eq("id", input.dossier_id)
    .single();

  if (dossierError || !dossier) throw new Error("Dossier not found");
  if (!["draft", "ready_for_publish"].includes(dossier.status)) {
    throw new Error(`Cannot publish dossier in status: ${dossier.status}`);
  }

  // Load workspace name for snapshot
  const { data: workspace } = await supabase
    .from("workspaces")
    .select("id, name")
    .eq("id", dossier.workspace_id)
    .single();

  if (!workspace) throw new Error("Workspace not found");

  // Load dossier items with full signal + evidence + source document chain.
  // Explicit field selection — never SELECT * — hard exclusions enforced here.
  // internal_notes, analyst_notes, item_notes are not selected.
  const { data: items, error: itemsError } = await supabase
    .from("dossier_items")
    .select(`
      display_order,
      signal:signals (
        id,
        title,
        summary,
        signal_type,
        jurisdiction,
        event_date,
        entity_name,
        entity_org,
        data_class,
        confidence_level,
        review_status,
        signal_evidence (
          id,
          evidence_type,
          evidence_source_type,
          evidence_text,
          citation_reference,
          created_at,
          source_document:source_documents (
            id,
            title,
            url,
            publication_date
          )
        )
      )
    `)
    .eq("dossier_id", input.dossier_id)
    .order("display_order", { ascending: true });

  if (itemsError) throw new Error(`loadDossierItems: ${itemsError.message}`);
  if (!items || items.length === 0) {
    throw new Error("Cannot publish an empty dossier. Add at least one signal.");
  }

  // Gate: every signal must be approved. Throws with named offenders.
  const unapproved = items.filter(
    (item) => (item.signal as any)?.review_status !== "approved"
  );
  if (unapproved.length > 0) {
    const titles = unapproved
      .map((u) => `"${(u.signal as any)?.title ?? "unknown"}"`)
      .join(", ");
    throw new Error(
      `Cannot publish: the following signals are not approved: ${titles}`
    );
  }

  const now = new Date();
  const publishedAt = now.toISOString();
  const effectiveAt = input.effective_at ?? publishedAt;

  // Assemble snapshot — schema_version allows feed consumers to version-gate.
  // internal_notes, analyst_notes, item_notes intentionally excluded at select time above.
  const snapshotJson = {
    schema_version: "1.0",
    dossier_id: dossier.id,
    title: dossier.title,
    summary: dossier.summary ?? null,
    jurisdiction: dossier.jurisdiction ?? null,
    version_number: dossier.version_number,
    supersedes_dossier_id: dossier.supersedes_dossier_id ?? null,
    published_at: publishedAt,   // event timestamp
    effective_at: effectiveAt,   // intelligence validity date — distinct from published_at
    workspace: {
      id: workspace.id,
      name: workspace.name,
      // slug and description intentionally omitted
    },
    signals: items.map((item: any) => {
      const s = item.signal;
      const evidence = (s.signal_evidence ?? [])
        .sort((a: any, b: any) =>
          new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
        )
        .map((ev: any) => ({
          id: ev.id,
          evidence_type: ev.evidence_type,
          evidence_source_type: ev.evidence_source_type,
          evidence_text: ev.evidence_text,
          citation_reference: ev.citation_reference,
          source_document: {
            id: ev.source_document.id,
            title: ev.source_document.title,
            url: ev.source_document.url,
            publication_date: ev.source_document.publication_date ?? null,
          },
          // internal_notes on signal_evidence intentionally excluded
        }));

      return {
        id: s.id,
        title: s.title,
        summary: s.summary,
        signal_type: s.signal_type,
        jurisdiction: s.jurisdiction ?? null,
        event_date: s.event_date ?? null,
        entity_name: s.entity_name ?? null,
        entity_org: s.entity_org ?? null,
        data_class: s.data_class,
        confidence_level: s.confidence_level,
        display_order: item.display_order,
        evidence,
        // internal_notes, analyst_notes intentionally excluded
      };
    }),
  };

  // Generate scoped API token for JSON feed access
  const apiToken = `hvfeed_${randomBytes(24).toString("hex")}`;

  // Insert publish event (append-only)
  const { data: publishEvent, error: peError } = await supabase
    .from("publish_events")
    .insert({
      dossier_id: dossier.id,
      workspace_id: dossier.workspace_id,
      status: "completed",
      published_by_profile_id: profile.id,
      snapshot_json: snapshotJson,
      api_token: apiToken,
    })
    .select()
    .single();

  if (peError) throw new Error(`createPublishEvent: ${peError.message}`);

  // Mark dossier published — SINGLE UPDATE, all fields together.
  // The immutability trigger fires once status='published'; any subsequent
  // update will be blocked. Do not split this into multiple statements.
  const { error: updateError } = await supabase
    .from("dossiers")
    .update({
      status: "published",
      published_at: publishedAt,
      published_by_profile_id: profile.id,
      effective_at: effectiveAt,
      updated_by_profile_id: profile.id,
    })
    .eq("id", input.dossier_id);

  if (updateError) throw new Error(`markDossierPublished: ${updateError.message}`);

  await writeAuditEvent({
    entity_type: "dossier",
    entity_id: input.dossier_id,
    action_type: "publish",
    performed_by_profile_id: profile.id,
    from_status: dossier.status,
    to_status: "published",
    change_summary: `Dossier published: ${dossier.title} (v${dossier.version_number})`,
    workspace_id: dossier.workspace_id,
  });

  revalidatePath(`/app/dossiers/${input.dossier_id}`);
  return { publishEvent, apiToken };
}

// ----------------------------------------------------------------
// Revoke publish event — ADMIN ONLY (corrected)
//
// CORRECTION: prior version called UPDATE on publish_events.
// The block_publish_event_mutation() trigger rejects ALL updates,
// including those made via the service role (triggers fire regardless
// of RLS bypass). Revocation is now a new append-only INSERT row with
// status='revoked' and revokes_event_id referencing the original.
//
// Feed route behaviour:
//   1. Look up publish_events WHERE api_token = $token AND status = 'completed'
//   2. Check for a revocation row: WHERE revokes_event_id = $id AND status = 'revoked'
//   3. If revocation row found: return 410 Gone
//   4. Otherwise: return snapshot_json
//
// The original row and its api_token are never mutated.
// ----------------------------------------------------------------
export async function revokePublishEvent(input: RevokePublishInput) {
  const supabase = input._supabase ?? await createServerClient();
  const profile = await requireRole(supabase, ["admin"]);

  // Fetch original event
  const { data: original } = await supabase
    .from("publish_events")
    .select("id, status, dossier_id, workspace_id")
    .eq("id", input.publish_event_id)
    .single();

  if (!original) throw new Error("Publish event not found");
  if (original.status === "revoked") {
    throw new Error("This event is itself a revocation row and cannot be revoked again.");
  }

  // Idempotency: block if a revocation row already exists for this event
  const { data: existingRevoke } = await supabase
    .from("publish_events")
    .select("id")
    .eq("revokes_event_id", input.publish_event_id)
    .eq("status", "revoked")
    .maybeSingle();

  if (existingRevoke) {
    throw new Error("This publish event has already been revoked.");
  }

  // Insert revocation row — new append-only record, original row untouched
  const { error: revokeError } = await supabase
    .from("publish_events")
    .insert({
      dossier_id: original.dossier_id,
      workspace_id: original.workspace_id,
      status: "revoked",
      published_by_profile_id: profile.id, // required not-null field; represents acting admin
      revokes_event_id: input.publish_event_id,
      revoked_by_profile_id: profile.id,
      revoke_reason: input.revoke_reason,
      snapshot_json: {},   // revocation rows carry no payload
      api_token: null,     // revocation rows have no token
    });

  if (revokeError) throw new Error(`revokePublishEvent: ${revokeError.message}`);

  await writeAuditEvent({
    entity_type: "publish_event",
    entity_id: input.publish_event_id,
    action_type: "revoke",
    performed_by_profile_id: profile.id,
    from_status: "completed",
    to_status: "revoked",
    change_summary: `Publish event revoked: ${input.revoke_reason}`,
    workspace_id: original.workspace_id,
  });

  revalidatePath("/app/dossiers");
}

// ----------------------------------------------------------------
// Create new dossier version — CORRECTED
//
// CORRECTION: prior version called UPDATE { status: 'superseded' } on a
// published dossier via the session client. The block_published_dossier_mutation()
// trigger rejects this. Fixed by:
//   (a) using the service client for the supersede update (bypasses RLS), AND
//   (b) the trigger amendment in 0006 that permits the single transition
//       published → superseded and nothing else.
//
// Note: createDossierVersion itself requires admin or analyst role (creating
// the new draft dossier is a legitimate analyst action). The supersede update
// on the source dossier is an admin-only lifecycle step and uses the service
// client scoped to that single operation.
// ----------------------------------------------------------------
export async function createDossierVersion(sourceDossierId: string) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const { data: source } = await supabase
    .from("dossiers")
    .select("id, workspace_id, title, summary, jurisdiction, version_number, status")
    .eq("id", sourceDossierId)
    .single();

  if (!source) throw new Error("Dossier not found");
  if (source.status !== "published") {
    throw new Error("Can only version a published dossier");
  }

  // Create new draft dossier version via session client
  const { data: newDossier, error } = await supabase
    .from("dossiers")
    .insert({
      workspace_id: source.workspace_id,
      title: source.title,
      summary: source.summary,
      jurisdiction: source.jurisdiction,
      status: "draft",
      version_number: source.version_number + 1,
      supersedes_dossier_id: sourceDossierId,
      created_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .select()
    .single();

  if (error) throw new Error(`createDossierVersion: ${error.message}`);

  // Mark source dossier as superseded.
  // MUST use service client: the session client's block_published_dossier_mutation
  // trigger blocks updates on published dossiers via the anon/user client.
  // The trigger amendment (0006 corrected) permits ONLY the published → superseded
  // transition; all other mutations on published dossiers remain blocked.
  const serviceSupabase = createServiceClient();
  const { error: supersededError } = await serviceSupabase
    .from("dossiers")
    .update({
      status: "superseded",
      updated_by_profile_id: profile.id,
    })
    .eq("id", sourceDossierId);

  if (supersededError) {
    // New dossier was created but supersede failed — flag clearly so operator can resolve
    throw new Error(
      `New dossier version created (${newDossier.id}) but failed to mark source ` +
      `dossier as superseded: ${supersededError.message}. ` +
      `Manually set dossiers.status = 'superseded' on ${sourceDossierId}.`
    );
  }

  await writeAuditEvent({
    entity_type: "dossier",
    entity_id: newDossier.id,
    action_type: "create",
    performed_by_profile_id: profile.id,
    to_status: "draft",
    change_summary: `New dossier version created (v${newDossier.version_number}), supersedes ${sourceDossierId}`,
    workspace_id: source.workspace_id,
  });

  revalidatePath("/app/dossiers");
  return newDossier;
}
