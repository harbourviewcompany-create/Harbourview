// tests/golden-path.test.ts
// Harbourview Production Spine — golden path and negative-path acceptance tests
// ADR-001 acceptance criteria from Section 17 of Engineering Takeover Pack V2
//
// Run against a live Supabase project with seed data applied (APPLY_ALL.sql).
// next/headers and next/cache are mocked via tests/setup.ts (vitest setupFiles).
// Server actions that need an authenticated session receive the signed-in
// adminClient via _supabase — the standard Supabase server action test pattern.
//
// Required env (all set in .env.local):
//   NEXT_PUBLIC_SUPABASE_URL
//   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
//   SUPABASE_SERVICE_ROLE_KEY
//   TEST_ADMIN_EMAIL / TEST_ADMIN_PASSWORD
//   TEST_ANALYST_EMAIL / TEST_ANALYST_PASSWORD
//   APP_URL

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { describe, it, expect, beforeAll } from "vitest";
import { publishDossier, revokePublishEvent } from "@/lib/actions/dossiers";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;
type TestSupabaseClient = SupabaseClient<any, "public", any>;

// Service client — bypasses RLS, used for setup/verification queries only
const service: TestSupabaseClient = createClient<any, "public", any>(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function signIn(email: string, password: string): Promise<TestSupabaseClient> {
  const client: TestSupabaseClient = createClient<any, "public", any>(
    SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!
  );
  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw new Error(`signIn failed for ${email}: ${error.message}`);
  return client;
}

// ================================================================
// Shared state — populated as tests run in sequence
// ================================================================
let adminClient: TestSupabaseClient;
let analystClient: TestSupabaseClient;

let sourceId: string;
let documentId: string;
let signalId: string;
let dossierId: string;
let publishEventId: string;
let apiToken: string;
let workspaceId: string;

beforeAll(async () => {
  adminClient = await signIn(process.env.TEST_ADMIN_EMAIL!, process.env.TEST_ADMIN_PASSWORD!);
  analystClient = await signIn(process.env.TEST_ANALYST_EMAIL!, process.env.TEST_ANALYST_PASSWORD!);

  // Resolve seed workspace ID by slug (set in 0009_seed_data.sql)
  const { data: ws } = await service
    .from("workspaces")
    .select("id")
    .eq("slug", "germany-intelligence")
    .single();
  workspaceId = ws!.id;
});

// ================================================================
// Golden path — 10 tests, run in order
// ================================================================
describe("Golden path", () => {

  it("1. analyst creates a source", async () => {
    const { data, error } = await analystClient
      .from("sources")
      .insert({
        name: "Tilray Germany Press Room",
        canonical_url: "https://ir.tilray.com/press-releases",
        domain: "tilray.com",
        source_tier: "company_primary",
        status: "draft",
        jurisdiction: "DE",
        entity_type: "company",
        contact_org: "Tilray Brands Inc",
      })
      .select()
      .single();

    expect(error).toBeNull();
    expect(data).toBeDefined();
    sourceId = data!.id;
  });

  it("2. analyst creates a source document (URL-only, ADR-001 D2)", async () => {
    const { data, error } = await analystClient
      .from("source_documents")
      .insert({
        source_id: sourceId,
        title: "Tilray Q1 2025 Germany Distribution Update",
        url: "https://ir.tilray.com/press-releases/2025/01/15/tilray-germany-q1-update",
        publication_date: "2025-01-15",
        status: "captured",
      })
      .select()
      .single();

    expect(error).toBeNull();
    documentId = data!.id;
  });

  it("3. analyst creates a signal", async () => {
    const { data, error } = await analystClient
      .from("signals")
      .insert({
        title: "Tilray expands German pharmacy distribution network — Q1 2025",
        summary:
          "Tilray announced expansion of its German pharmacy distribution to 2,400 pharmacies in Q1 2025, up from 1,800 in Q4 2024.",
        signal_type: "market_entry",
        jurisdiction: "DE",
        event_date: "2025-01-15",
        entity_name: "Tilray Brands Inc",
        entity_org: "Tilray Brands Inc",
        data_class: "observed",
        confidence_level: "high",
        review_status: "draft",
        visibility_scope: "internal",
        source_id: sourceId,
      })
      .select()
      .single();

    expect(error).toBeNull();
    signalId = data!.id;
  });

  it("4. analyst attaches human-verified evidence", async () => {
    const { data, error } = await analystClient
      .from("signal_evidence")
      .insert({
        signal_id: signalId,
        source_document_id: documentId,
        evidence_type: "paraphrased_fact",
        evidence_source_type: "human",
        evidence_text:
          "Tilray stated its German pharmacy network grew to 2,400 locations in Q1 2025 from 1,800 in Q4 2024.",
        citation_reference: "Press release paragraph 3, January 15 2025",
      })
      .select()
      .single();

    expect(error).toBeNull();
    expect(data).toBeDefined();
  });

  it("5. analyst submits signal for review", async () => {
    const analystId = (await analystClient.auth.getUser()).data.user!.id;

    const { error: signalError } = await analystClient
      .from("signals")
      .update({ review_status: "in_review", submitted_at: new Date().toISOString() })
      .eq("id", signalId);
    expect(signalError).toBeNull();

    const { error: rqError } = await analystClient
      .from("review_queue_items")
      .insert({ signal_id: signalId, status: "pending", submitted_by_profile_id: analystId });
    expect(rqError).toBeNull();
  });

  it("6. admin approves the signal", async () => {
    const { error } = await adminClient
      .from("signals")
      .update({ review_status: "approved", reviewed_at: new Date().toISOString() })
      .eq("id", signalId);
    expect(error).toBeNull();

    // Confirm approval persisted
    const { data: updated } = await service
      .from("signals")
      .select("review_status")
      .eq("id", signalId)
      .single();
    expect(updated!.review_status).toBe("approved");
  });

  it("7. admin creates a dossier and adds the approved signal", async () => {
    const { data: dossier, error: de } = await adminClient
      .from("dossiers")
      .insert({
        workspace_id: workspaceId,
        title: "Germany Intelligence Brief — Q1 2025",
        status: "draft",
        jurisdiction: "DE",
      })
      .select()
      .single();

    expect(de).toBeNull();
    dossierId = dossier!.id;

    const { error: ie } = await adminClient
      .from("dossier_items")
      .insert({ dossier_id: dossierId, signal_id: signalId, display_order: 1 });
    expect(ie).toBeNull();
  });

  it("8. admin publishes via server action; snapshot has full evidence chain", async () => {
    // Call the real publishDossier() server action with adminClient injected.
    // This is the full end-to-end path: signal join → evidence join → source_document join
    // → snapshot assembly → publish_events INSERT → dossiers UPDATE.
    const result = await publishDossier({ dossier_id: dossierId, _supabase: adminClient });

    publishEventId = result.publishEvent.id;
    apiToken = result.apiToken;

    expect(result.publishEvent).toBeDefined();
    expect(result.apiToken).toMatch(/^hvfeed_/);

    const snapshot = result.publishEvent.snapshot_json as any;
    expect(snapshot.schema_version).toBe("1.0");
    expect(snapshot.signals).toBeDefined();
    expect(snapshot.signals.length).toBeGreaterThan(0);
    expect(snapshot.signals[0].evidence.length).toBeGreaterThan(0);
    expect(snapshot.signals[0].evidence[0].source_document.url).toBeTruthy();
  });

  it("9. JSON feed returns snapshot for valid token; no internal fields present", async () => {
    const res = await fetch(`${process.env.APP_URL}/api/feed/${apiToken}`);
    const body = await res.json();
    const bodyStr = JSON.stringify(body);

    expect(res.status).toBe(200);
    expect(body.dossier.dossier_id).toBe(dossierId);
    expect(body.dossier.signals.length).toBeGreaterThan(0);
    expect(body.dossier.signals[0].evidence).toBeDefined();

    // None of these fields should appear anywhere in the serialised response
    expect(bodyStr).not.toContain("internal_notes");
    expect(bodyStr).not.toContain("analyst_notes");
    expect(bodyStr).not.toContain("reviewer_notes");
    expect(bodyStr).not.toContain("item_notes");
  });

  it("10. audit trail contains all key events for the signal", async () => {
    const { data } = await adminClient
      .from("audit_events")
      .select("action_type")
      .eq("entity_id", signalId);

    const actions = data?.map((r: { action_type: string }) => r.action_type) ?? [];
    expect(actions).toContain("create");
    expect(actions).toContain("submit_for_review");
    expect(actions).toContain("approve");
  });

});

// ================================================================
// Negative-path tests — ADR-001 acceptance criteria
// ================================================================
describe("Negative path", () => {

  it("N1. cannot approve a signal with zero evidence (DB trigger)", async () => {
    const { data: bare } = await analystClient
      .from("signals")
      .insert({
        title: "No-evidence signal",
        summary: "Test",
        signal_type: "test",
        data_class: "unverified",
        confidence_level: "low",
        review_status: "in_review",
        visibility_scope: "internal",
      })
      .select()
      .single();

    const { error } = await adminClient
      .from("signals")
      .update({ review_status: "approved" })
      .eq("id", bare!.id);

    expect(error).not.toBeNull();
    expect(error!.message).toContain("evidence");
  });

  it("N2. cannot publish a dossier containing a draft signal (app-layer gate)", async () => {
    const { data: draftSignal } = await analystClient
      .from("signals")
      .insert({
        title: "Draft signal — publish gate test",
        summary: "Test",
        signal_type: "test",
        data_class: "observed",
        confidence_level: "low",
        review_status: "draft",
        visibility_scope: "internal",
      })
      .select()
      .single();

    const { data: badDossier } = await adminClient
      .from("dossiers")
      .insert({ workspace_id: workspaceId, title: "Bad dossier — draft signal", status: "draft" })
      .select()
      .single();

    await adminClient
      .from("dossier_items")
      .insert({ dossier_id: badDossier!.id, signal_id: draftSignal!.id, display_order: 1 });

    await expect(
      publishDossier({ dossier_id: badDossier!.id, _supabase: adminClient })
    ).rejects.toThrow("not approved");
  });

  it("N3. published dossier cannot be mutated in place (DB trigger)", async () => {
    const { error } = await adminClient
      .from("dossiers")
      .update({ title: "Attempted mutation" })
      .eq("id", dossierId);

    expect(error).not.toBeNull();
    expect(error!.message).toContain("immutable");
  });

  it("N4. revoked feed token returns 410 Gone", async () => {
    // Revocation is an INSERT of a new row — never an UPDATE on the original.
    // block_publish_event_mutation() rejects all updates including via service role.
    await revokePublishEvent({
      publish_event_id: publishEventId,
      revoke_reason: "Test revocation — N4 negative path",
      _supabase: adminClient,
    });

    // Revocation row must exist and reference the original
    const { data: revokeRow } = await service
      .from("publish_events")
      .select("id, status, revokes_event_id")
      .eq("revokes_event_id", publishEventId)
      .eq("status", "revoked")
      .single();

    expect(revokeRow).toBeDefined();
    expect(revokeRow!.revokes_event_id).toBe(publishEventId);

    // Original row must remain untouched
    const { data: original } = await service
      .from("publish_events")
      .select("status")
      .eq("id", publishEventId)
      .single();
    expect(original!.status).toBe("completed");

    // Feed returns 410 Gone for the revoked token
    const res = await fetch(`${process.env.APP_URL}/api/feed/${apiToken}`);
    const body = await res.json();
    expect(res.status).toBe(410);
    expect(body.revoked).toBe(true);
  });

  it("N5. invalid feed token returns 404", async () => {
    const res = await fetch(`${process.env.APP_URL}/api/feed/invalid_token_xyz`);
    expect(res.status).toBe(404);
  });

  it("N6. duplicate source document URL is blocked by partial unique index", async () => {
    const url = "https://example.com/duplicate-test-doc-unique";

    await service
      .from("source_documents")
      .insert({ source_id: sourceId, title: "First doc", url, status: "captured" });

    const { error } = await analystClient
      .from("source_documents")
      .insert({ source_id: sourceId, title: "Duplicate doc", url, status: "captured" });

    expect(error).not.toBeNull();
  });

  it("N7. analyst cannot update review_queue_items (RLS blocks)", async () => {
    const { error } = await analystClient
      .from("review_queue_items")
      .update({ status: "approved" })
      .eq("signal_id", signalId);

    expect(error).not.toBeNull();
  });

  it("N8. cannot revoke the same publish event twice (idempotency guard)", async () => {
    // publishEventId was revoked in N4; attempting again must throw
    await expect(
      revokePublishEvent({
        publish_event_id: publishEventId,
        revoke_reason: "Second revocation attempt",
        _supabase: adminClient,
      })
    ).rejects.toThrow("already been revoked");
  });

});
