// lib/actions/signals.ts (corrected)
// Harbourview Production Spine — signal creation, evidence attachment, review workflow
// ADR-001 D1: approve/reject are admin-only. Analysts can create, edit drafts, and submit.
// ADR-001 D3: entity_name and entity_org are plain text.
//
// CORRECTION vs prior version:
//
// [1] approveSignal review queue resolution FIXED
//   Prior version resolved the review queue item with:
//     .eq("status", "under_review")
//   submitSignalForReview inserts the queue item with status = 'pending'.
//   There is no action that transitions pending → under_review, so the
//   approve update matched zero rows silently — queue item stayed 'pending'
//   after the signal was approved.
//
//   Fixed by targeting .in("status", ["pending", "under_review"]) so approval
//   works whether or not an admin has explicitly picked up the item first.
//   Same fix applied to rejectSignal for consistency.
//
// [2] rejectSignal review queue resolution — same fix applied
//   Same root cause, same fix.

"use server";

import { createServerClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { writeAuditEvent } from "@/lib/audit";
import { requireRole } from "@/lib/auth";

export type CreateSignalInput = {
  title: string;
  summary: string;
  signal_type: string;
  jurisdiction?: string;
  event_date?: string;
  entity_name?: string;
  entity_org?: string;
  data_class: "observed" | "derived" | "inferred" | "unverified";
  confidence_level: "low" | "medium" | "high" | "confirmed";
  visibility_scope?: "internal" | "workspace" | "public_future_reserved";
  source_id?: string;
  internal_notes?: string;
  analyst_notes?: string;
};

export type AttachSignalEvidenceInput = {
  signal_id: string;
  source_document_id: string;
  evidence_type:
    | "direct_quote"
    | "paraphrased_fact"
    | "date_confirmation"
    | "supporting_context"
    | "secondary_reference";
  evidence_source_type: "human" | "ai_assisted";
  evidence_text: string;
  citation_reference: string;
  internal_notes?: string;
};

export type ApproveSignalInput = {
  signal_id: string;
  reviewer_notes?: string;
};

export type RejectSignalInput = {
  signal_id: string;
  rejection_reason: string;
};

// ----------------------------------------------------------------
// Create signal
// ----------------------------------------------------------------
export async function createSignal(input: CreateSignalInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const { data, error } = await supabase
    .from("signals")
    .insert({
      ...input,
      review_status: "draft",
      visibility_scope: input.visibility_scope ?? "internal",
      created_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .select()
    .single();

  if (error) throw new Error(`createSignal: ${error.message}`);

  await writeAuditEvent({
    entity_type: "signal",
    entity_id: data.id,
    action_type: "create",
    performed_by_profile_id: profile.id,
    to_status: "draft",
    change_summary: `Signal created: ${data.title}`,
  });

  revalidatePath("/app/signals");
  return data;
}

// ----------------------------------------------------------------
// Attach evidence
// ----------------------------------------------------------------
export async function attachSignalEvidence(input: AttachSignalEvidenceInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const { data: signal } = await supabase
    .from("signals")
    .select("review_status")
    .eq("id", input.signal_id)
    .single();

  if (!signal) throw new Error("Signal not found");
  if (!["draft", "in_review"].includes(signal.review_status)) {
    throw new Error(
      `Cannot attach evidence to a signal in status: ${signal.review_status}`
    );
  }

  const { data, error } = await supabase
    .from("signal_evidence")
    .insert({
      ...input,
      created_by_profile_id: profile.id,
    })
    .select()
    .single();

  if (error) throw new Error(`attachSignalEvidence: ${error.message}`);

  await writeAuditEvent({
    entity_type: "signal",
    entity_id: input.signal_id,
    action_type: "update",
    performed_by_profile_id: profile.id,
    change_summary: `Evidence attached (${input.evidence_type}, ${input.evidence_source_type})`,
  });

  revalidatePath(`/app/signals/${input.signal_id}`);
  return data;
}

// ----------------------------------------------------------------
// Submit for review
// ----------------------------------------------------------------
export async function submitSignalForReview(signalId: string) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const { data: signal } = await supabase
    .from("signals")
    .select("review_status, title")
    .eq("id", signalId)
    .single();

  if (!signal) throw new Error("Signal not found");
  if (signal.review_status !== "draft") {
    throw new Error(
      `Signal must be in draft to submit for review. Current status: ${signal.review_status}`
    );
  }

  // Early evidence check — DB trigger also guards on approval, this gives a
  // better error message at submission time rather than at approval time.
  const { count } = await supabase
    .from("signal_evidence")
    .select("id", { count: "exact", head: true })
    .eq("signal_id", signalId);

  if (!count || count === 0) {
    throw new Error(
      "Signal must have at least one evidence record before submitting for review."
    );
  }

  const { data: updated, error: signalError } = await supabase
    .from("signals")
    .update({
      review_status: "in_review",
      submitted_at: new Date().toISOString(),
      submitted_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .eq("id", signalId)
    .select()
    .single();

  if (signalError) throw new Error(`submitSignalForReview: ${signalError.message}`);

  const { error: rqError } = await supabase.from("review_queue_items").insert({
    signal_id: signalId,
    status: "pending",
    submitted_by_profile_id: profile.id,
  });

  if (rqError) throw new Error(`createReviewQueueItem: ${rqError.message}`);

  await writeAuditEvent({
    entity_type: "signal",
    entity_id: signalId,
    action_type: "submit_for_review",
    performed_by_profile_id: profile.id,
    from_status: "draft",
    to_status: "in_review",
    change_summary: `Signal submitted for review: ${signal.title}`,
  });

  revalidatePath(`/app/signals/${signalId}`);
  revalidatePath("/app/review");
  return updated;
}

// ----------------------------------------------------------------
// Approve signal — ADMIN ONLY (ADR-001 D1)
// ----------------------------------------------------------------
export async function approveSignal(input: ApproveSignalInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin"]);

  const { data: signal } = await supabase
    .from("signals")
    .select("review_status, title")
    .eq("id", input.signal_id)
    .single();

  if (!signal) throw new Error("Signal not found");
  if (signal.review_status !== "in_review") {
    throw new Error(
      `Signal must be in_review to approve. Current status: ${signal.review_status}`
    );
  }

  // App-layer evidence checks — DB trigger check_signal_has_evidence also
  // enforces both conditions; these give clearer error messages.
  const { count: evidenceCount } = await supabase
    .from("signal_evidence")
    .select("id", { count: "exact", head: true })
    .eq("signal_id", input.signal_id);

  if (!evidenceCount || evidenceCount === 0) {
    throw new Error("Cannot approve: signal has no evidence records.");
  }

  const { count: humanEvidenceCount } = await supabase
    .from("signal_evidence")
    .select("id", { count: "exact", head: true })
    .eq("signal_id", input.signal_id)
    .eq("evidence_source_type", "human");

  if (!humanEvidenceCount || humanEvidenceCount === 0) {
    throw new Error(
      "Cannot approve: at least one human-verified evidence record is required. " +
      "AI-assisted evidence alone is insufficient."
    );
  }

  const { data: updated, error: signalError } = await supabase
    .from("signals")
    .update({
      review_status: "approved",
      reviewed_at: new Date().toISOString(),
      reviewed_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .eq("id", input.signal_id)
    .select()
    .single();

  if (signalError) throw new Error(`approveSignal: ${signalError.message}`);

  // CORRECTED: target both 'pending' and 'under_review'.
  // submitSignalForReview inserts queue items with status='pending'.
  // No action currently transitions pending → under_review, so targeting
  // only 'under_review' silently matched zero rows in the prior version.
  const { error: rqError } = await supabase
    .from("review_queue_items")
    .update({
      status: "approved",
      resolved_at: new Date().toISOString(),
      resolved_by_profile_id: profile.id,
      reviewer_notes: input.reviewer_notes ?? null,
    })
    .eq("signal_id", input.signal_id)
    .in("status", ["pending", "under_review"]);

  if (rqError) {
    // Log but don't fail the approval — signal state is already committed.
    // Queue item inconsistency is recoverable; signal approval is not.
    console.error(
      `[approveSignal] Review queue item update failed for signal ${input.signal_id}: ${rqError.message}`
    );
  }

  await writeAuditEvent({
    entity_type: "signal",
    entity_id: input.signal_id,
    action_type: "approve",
    performed_by_profile_id: profile.id,
    from_status: "in_review",
    to_status: "approved",
    change_summary: "Signal approved by admin",
  });

  revalidatePath(`/app/signals/${input.signal_id}`);
  revalidatePath("/app/review");
  return updated;
}

// ----------------------------------------------------------------
// Reject signal — ADMIN ONLY (ADR-001 D1)
// ----------------------------------------------------------------
export async function rejectSignal(input: RejectSignalInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin"]);

  const { data: signal } = await supabase
    .from("signals")
    .select("review_status, title")
    .eq("id", input.signal_id)
    .single();

  if (!signal) throw new Error("Signal not found");
  if (signal.review_status !== "in_review") {
    throw new Error(
      `Signal must be in_review to reject. Current status: ${signal.review_status}`
    );
  }

  const { data: updated, error } = await supabase
    .from("signals")
    .update({
      review_status: "rejected",
      reviewed_at: new Date().toISOString(),
      reviewed_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .eq("id", input.signal_id)
    .select()
    .single();

  if (error) throw new Error(`rejectSignal: ${error.message}`);

  // CORRECTED: same fix as approveSignal — target both 'pending' and 'under_review'
  const { error: rqError } = await supabase
    .from("review_queue_items")
    .update({
      status: "rejected",
      resolved_at: new Date().toISOString(),
      resolved_by_profile_id: profile.id,
      rejection_reason: input.rejection_reason,
    })
    .eq("signal_id", input.signal_id)
    .in("status", ["pending", "under_review"]);

  if (rqError) {
    console.error(
      `[rejectSignal] Review queue item update failed for signal ${input.signal_id}: ${rqError.message}`
    );
  }

  await writeAuditEvent({
    entity_type: "signal",
    entity_id: input.signal_id,
    action_type: "reject",
    performed_by_profile_id: profile.id,
    from_status: "in_review",
    to_status: "rejected",
    change_summary: `Signal rejected: ${input.rejection_reason}`,
  });

  revalidatePath(`/app/signals/${input.signal_id}`);
  revalidatePath("/app/review");
  return updated;
}
