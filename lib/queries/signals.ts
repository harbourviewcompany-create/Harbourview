import { getScopedSupabase, normalizeLike, toArray } from "@/lib/queries/_shared";
function mapSignalRow(row:any) { return { id:row.id, title:row.title, summary:row.summary, signal_type:row.signal_type, jurisdiction:row.jurisdiction, event_date:row.event_date, entity_name:row.entity_name, entity_org:row.entity_org, data_class:row.data_class, confidence_level:row.confidence_level, review_status:row.review_status, visibility_scope:row.visibility_scope, source_id:row.source_id, created_at:row.created_at, updated_at:row.updated_at, evidence_count:toArray(row.signal_evidence).length, human_evidence_count:toArray(row.signal_evidence).filter((e:any)=>e.evidence_source_type==="human").length, source_name:row.sources?.name ?? null, source_tier:row.sources?.source_tier ?? null }; }
export async function getSignals(filters:any = {}) {
  const { supabase } = await getScopedSupabase();
  let query = supabase.from("signals").select(`id,title,summary,signal_type,jurisdiction,event_date,entity_name,entity_org,data_class,confidence_level,review_status,visibility_scope,source_id,created_at,updated_at,sources(id,name,source_tier),signal_evidence(id,evidence_source_type)`).order("created_at", { ascending: false });
  if (filters.status) query = query.eq("review_status", filters.status);
  if (filters.jurisdiction) query = query.eq("jurisdiction", filters.jurisdiction);
  if (filters.data_class) query = query.eq("data_class", filters.data_class);
  if (filters.confidence) query = query.eq("confidence_level", filters.confidence);
  const search = normalizeLike(filters.q); if (search) query = query.or(`title.ilike.${search},summary.ilike.${search},entity_name.ilike.${search},entity_org.ilike.${search}`);
  const { data, error } = await query; if (error) throw new Error(`getSignals: ${error.message}`); return toArray(data).map(mapSignalRow);
}
export async function getSignalDetail(signalId:string) {
  const { supabase } = await getScopedSupabase();
  const [{ data:signal, error:signalError }, { data:reviewData }, { data:evidenceData, error:evidenceError }] = await Promise.all([
    supabase.from("signals").select(`id,title,summary,signal_type,jurisdiction,event_date,entity_name,entity_org,data_class,confidence_level,review_status,visibility_scope,source_id,created_at,updated_at,internal_notes,analyst_notes,sources(id,name,source_tier),signal_evidence(id,evidence_source_type)`).eq("id", signalId).maybeSingle(),
    supabase.from("review_queue_items").select(`id,signal_id,status,assigned_to_profile_id,submitted_by_profile_id,reviewer_notes,rejection_reason,return_reason,resolved_at,created_at,updated_at`).eq("signal_id", signalId).order("created_at", { ascending: false }).limit(1).maybeSingle(),
    supabase.from("signal_evidence").select(`id,signal_id,source_document_id,evidence_type,evidence_source_type,evidence_text,citation_reference,created_at,source_documents(title,url,publication_date)`).eq("signal_id", signalId).order("created_at", { ascending: true }),
  ]);
  if (signalError) throw new Error(`getSignalDetail: ${signalError.message}`);
  if (evidenceError) throw new Error(`getSignalDetail evidence: ${evidenceError.message}`);
  if (!signal) return null;
  const base = mapSignalRow(signal);
  return { ...base, internal_notes: signal.internal_notes, analyst_notes: signal.analyst_notes, review_queue_item: reviewData ? { ...reviewData, signal_title: signal.title, signal_summary: signal.summary, data_class: signal.data_class, confidence_level: signal.confidence_level, jurisdiction: signal.jurisdiction, signal_type: signal.signal_type, evidence_count: base.evidence_count, human_evidence_count: base.human_evidence_count } : null, evidence: toArray(evidenceData).map((row:any)=>({ id:row.id, signal_id:row.signal_id, source_document_id:row.source_document_id, evidence_type:row.evidence_type, evidence_source_type:row.evidence_source_type, evidence_text:row.evidence_text, citation_reference:row.citation_reference, created_at:row.created_at, source_document_title:row.source_documents?.title ?? null, source_document_url:row.source_documents?.url ?? null, source_document_publication_date:row.source_documents?.publication_date ?? null })) };
}
