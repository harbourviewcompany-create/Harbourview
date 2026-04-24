import { getScopedSupabase, toArray } from "@/lib/queries/_shared";

export async function getReviewQueue() {
  const { supabase } = await getScopedSupabase();
  const { data, error } = await supabase
    .from("review_queue_items")
    .select(`
      id,
      signal_id,
      status,
      assigned_to_profile_id,
      submitted_by_profile_id,
      reviewer_notes,
      rejection_reason,
      return_reason,
      resolved_at,
      created_at,
      updated_at,
      signals(
        id,
        title,
        summary,
        data_class,
        confidence_level,
        jurisdiction,
        signal_type,
        signal_evidence(id,evidence_source_type)
      )
    `)
    .eq("status", "pending")
    .order("created_at", { ascending: true });

  if (error) throw new Error(`getReviewQueue: ${error.message}`);

  return toArray(data).map((row: any) => {
    const signal = row.signals ?? {};
    const evidence = toArray(signal.signal_evidence);
    return {
      id: row.id,
      signal_id: row.signal_id,
      status: row.status,
      assigned_to_profile_id: row.assigned_to_profile_id,
      submitted_by_profile_id: row.submitted_by_profile_id,
      reviewer_notes: row.reviewer_notes,
      rejection_reason: row.rejection_reason,
      return_reason: row.return_reason,
      resolved_at: row.resolved_at,
      created_at: row.created_at,
      updated_at: row.updated_at,
      signal_title: signal.title ?? null,
      signal_summary: signal.summary ?? null,
      data_class: signal.data_class ?? null,
      confidence_level: signal.confidence_level ?? null,
      jurisdiction: signal.jurisdiction ?? null,
      signal_type: signal.signal_type ?? null,
      evidence_count: evidence.length,
      human_evidence_count: evidence.filter((e: any) => e.evidence_source_type === "human").length,
    };
  });
}
