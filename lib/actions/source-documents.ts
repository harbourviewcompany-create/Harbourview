// lib/actions/source-documents.ts
// Harbourview Production Spine — source document mutations
// ADR-001 D2: URL-only ingestion. url is required. No file upload.

"use server";

import { createServerClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { writeAuditEvent } from "@/lib/audit";
import { requireRole } from "@/lib/auth";
import { createHash } from "crypto";

export type CreateSourceDocumentInput = {
  source_id: string;
  title: string;
  url: string;
  publication_date?: string; // ISO date string YYYY-MM-DD
  parsed_content?: string;
  internal_notes?: string;
};

export async function createSourceDocument(input: CreateSourceDocumentInput) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  // Normalize URL — strip trailing slash, lowercase scheme+host
  const normalized = normalizeUrl(input.url);

  // Check for exact URL duplicate before insert
  const { data: existing } = await supabase
    .from("source_documents")
    .select("id, title")
    .eq("url", normalized)
    .neq("status", "archived")
    .maybeSingle();

  if (existing) {
    throw new Error(
      `Duplicate source document: a record with this URL already exists (id: ${existing.id}, title: "${existing.title}"). ` +
        `Use the existing record or archive it before creating a new one.`
    );
  }

  // Compute content hash if parsed_content is provided
  const content_hash = input.parsed_content
    ? createHash("sha256").update(input.parsed_content).digest("hex")
    : null;

  const status = input.parsed_content ? "parsed" : "captured";

  const { data, error } = await supabase
    .from("source_documents")
    .insert({
      source_id: input.source_id,
      title: input.title,
      url: normalized,
      publication_date: input.publication_date ?? null,
      status,
      parsed_content: input.parsed_content ?? null,
      content_hash,
      internal_notes: input.internal_notes ?? null,
      created_by_profile_id: profile.id,
      updated_by_profile_id: profile.id,
    })
    .select()
    .single();

  if (error) throw new Error(`createSourceDocument: ${error.message}`);

  await writeAuditEvent({
    entity_type: "source_document",
    entity_id: data.id,
    action_type: "create",
    performed_by_profile_id: profile.id,
    to_status: status,
    change_summary: `Source document captured: ${data.title}`,
  });

  revalidatePath(`/app/sources/${input.source_id}`);
  return data;
}

export async function markDocumentParsed(
  documentId: string,
  parsedContent: string
) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const content_hash = createHash("sha256")
    .update(parsedContent)
    .digest("hex");

  const { data, error } = await supabase
    .from("source_documents")
    .update({
      status: "parsed",
      parsed_content: parsedContent,
      content_hash,
      parse_error: null,
      updated_by_profile_id: profile.id,
    })
    .eq("id", documentId)
    .select()
    .single();

  if (error) throw new Error(`markDocumentParsed: ${error.message}`);

  await writeAuditEvent({
    entity_type: "source_document",
    entity_id: documentId,
    action_type: "update",
    performed_by_profile_id: profile.id,
    from_status: "captured",
    to_status: "parsed",
    change_summary: "Source document parsed and content captured",
  });

  revalidatePath(`/app/source-documents/${documentId}`);
  return data;
}

export async function markDocumentFailed(
  documentId: string,
  parseError: string
) {
  const supabase = await createServerClient();
  const profile = await requireRole(supabase, ["admin", "analyst"]);

  const { data, error } = await supabase
    .from("source_documents")
    .update({
      status: "failed",
      parse_error: parseError,
      updated_by_profile_id: profile.id,
    })
    .eq("id", documentId)
    .select()
    .single();

  if (error) throw new Error(`markDocumentFailed: ${error.message}`);

  await writeAuditEvent({
    entity_type: "source_document",
    entity_id: documentId,
    action_type: "update",
    performed_by_profile_id: profile.id,
    from_status: "captured",
    to_status: "failed",
    change_summary: `Document parse failed: ${parseError}`,
  });

  return data;
}

function normalizeUrl(raw: string): string {
  try {
    const u = new URL(raw.trim());
    // Lowercase scheme and host, remove trailing slash from pathname
    u.pathname = u.pathname.replace(/\/+$/, "") || "/";
    return u.toString().toLowerCase();
  } catch {
    // Not a valid URL — return trimmed original and let DB constraint catch it
    return raw.trim();
  }
}
