import { getDossierDetail } from "@/lib/queries/dossiers";
import { getSignalDetail } from "@/lib/queries/signals";
function issue(severity:"error"|"warning", code:string, message:string) { return { severity, code, message }; }
export async function buildPublishPreview(dossierId:string, effectiveAt?:string) {
  const dossier = await getDossierDetail(dossierId); if (!dossier) throw new Error("Dossier not found");
  const issues:any[] = []; const signalDetails = await Promise.all(dossier.items.map((item:any)=>getSignalDetail(item.signal_id)));
  let evidenceCount = 0; let humanEvidenceCount = 0;
  for (const [index, signal] of signalDetails.entries()) {
    const label = dossier.items[index]?.signal_title ?? `Signal ${index + 1}`;
    if (!signal) { issues.push(issue("error","SIGNAL_MISSING",`${label} could not be loaded for preview.`)); continue; }
    evidenceCount += signal.evidence_count; humanEvidenceCount += signal.human_evidence_count;
    if (signal.review_status !== "approved") issues.push(issue("error","SIGNAL_NOT_APPROVED",`${label} is ${signal.review_status} and cannot be published.`));
    if (signal.evidence_count < 1) issues.push(issue("error","SIGNAL_NO_EVIDENCE",`${label} has no evidence attached.`));
    if (signal.human_evidence_count < 1) issues.push(issue("error","SIGNAL_NO_HUMAN_EVIDENCE",`${label} has no human-verified evidence.`));
    if (!signal.summary?.trim()) issues.push(issue("warning","SIGNAL_SUMMARY_EMPTY",`${label} has an empty or weak summary.`));
    if (signal.data_class === "unverified") issues.push(issue("warning","SIGNAL_UNVERIFIED_CLASS",`${label} is still marked unverified.`));
  }
  if (dossier.items.length === 0) issues.push(issue("error","DOSSIER_EMPTY","The dossier has no signals."));
  const snapshot = { dossier_id:dossier.id, title:dossier.title, summary:dossier.summary, jurisdiction:dossier.jurisdiction, version_number:dossier.version_number, effective_at:effectiveAt ?? new Date().toISOString(), generated_at:new Date().toISOString(), signal_count:dossier.items.length, signals:signalDetails.filter(Boolean).map((signal:any)=>({ id:signal.id, title:signal.title, summary:signal.summary, signal_type:signal.signal_type, jurisdiction:signal.jurisdiction, event_date:signal.event_date, entity_name:signal.entity_name, entity_org:signal.entity_org, data_class:signal.data_class, confidence_level:signal.confidence_level, evidence_count:signal.evidence_count, human_evidence_count:signal.human_evidence_count })) };
  return { dossier_id:dossier.id, title:dossier.title, effective_at:effectiveAt ?? new Date().toISOString(), can_publish:!issues.some((x:any)=>x.severity==="error"), issues, snapshot, stats:{ signal_count:dossier.items.length, approved_signal_count:signalDetails.filter((s:any)=>s?.review_status==="approved").length, evidence_count:evidenceCount, human_evidence_count:humanEvidenceCount } };
}
