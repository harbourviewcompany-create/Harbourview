// lib/actions/sources.ts
// Harbourview Production Spine — source mutations
// ADR-001 D1: admin and analyst can create/edit sources. Admin only can archive.
// ADR-001 D3: contact_name and contact_org are plain text fields, no FK.

"use server";

import { createServerClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { writeAuditEvent } from "@/lib/audit";
import { requireRole } from "@/lib/auth";

export type CreateSourceInput = {
  name: string;
  canonical_url?: string;
  domain?: string;
  source_tier:
    | "official_primary"
    | "official_secondary"
    | "company_primary"
    | "trusted_secondary"
    | "media_secondary"
    | "community_low_trust";
  jurisdiction?: string;
  entity_type?: "person" | "company" | "regulator";
  contact_name?: string;
  contact_org?: string;
  description?: string;
  internal_notes?: string;
};

export type UpdateSourceInput = Partial<CreateSourceInput> & {
  id: string;
};

export async function createSource(input: CreateSourceInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const { data, error } = await supabase
    .from("sources")
    .insert({
      ...input,
      status: "draft",
      created_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .select()
    .single();

  if (error) throw new Error(`createSource: ${error.message}`);

  await writeAuditEvent({
    entity_type: "source",
    entity_id: data.id,
    action_type: "create",
    performed_by_profile_id: profile.id,
    to_status: "draft",
    change_summary: `Source created: ${data.name}`,
  });

  revalidatePath("/app/sources");
  return data;
}

export async function activateSource(sourceId: string) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const { data: existing, error: fetchError } = await supabase
    .from("sources")
    .select("id, name, status")
    .eq("id", sourceId)
    .single();

  if (fetchError || !existing) throw new Error("Source not found");
  if (existing.status !== "draft" && existing.status !== "paused") {
    throw new Error(`Cannot activate source in status: ${existing.status}`);
  }

  const { data, error } = await supabase
    .from("sources")
    .update({ status: "active", updated_by_profile_id: profile.id })
    .eq("id", sourceId)
    .select()
    .single();

  if (error) throw new Error(`activateSource: ${error.message}`);

  await writeAuditEvent({
    entity_type: "source",
    entity_id: sourceId,
    action_type: "update",
    performed_by_profile_id: profile.id,
    from_status: existing.status,
    to_status: "active",
    change_summary: `Source activated: ${existing.name}`,
  });

  revalidatePath("/app/sources");
  return data;
}

export async function archiveSource(sourceId: string) {
  const supabase = await createServerClient();
  // ADR-001 D1: only admin can archive
  const profile = await requireRole(supabase, ["admin"]);

  const { data: existing, error: fetchError } = await supabase
    .from("sources")
    .select("id, name, status")
    .eq("id", sourceId)
    .single();

  if (fetchError || !existing) throw new Error("Source not found");

  const { data, error } = await supabase
    .from("sources")
    .update({
      status: "archived",
      archived_at: new Date().toISOString(),
      archived_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .eq("id", sourceId)
    .select()
    .single();

  if (error) throw new Error(`archiveSource: ${error.message}`);

  await writeAuditEvent({
    entity_type: "source",
    entity_id: sourceId,
    action_type: "archive",
    performed_by_profile_id: profile.id,
    from_status: existing.status,
    to_status: "archived",
    change_summary: `Source archived: ${existing.name}`,
  });

  revalidatePath("/app/sources");
  return data;
}

export async function updateSource(input: UpdateSourceInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);
  const { id, ...fields } = input;

  const { data, error } = await supabase
    .from("sources")
    .update({ ...fields, updated_by_profile_id: profile.id })
    .eq("id", id)
    .select()
    .single();

  if (error) throw new Error(`updateSource: ${error.message}`);

  await writeAuditEvent({
    entity_type: "source",
    entity_id: id,
    action_type: "update",
    performed_by_profile_id: profile.id,
    change_summary: `Source updated`,
  });

  revalidatePath(`/app/sources/${id}`);
  return data;
}
