import { PageHeader, KV, StatusBadge, DataClassBadge, ConfidenceBadge } from "@/components/ui";
import { getSignalDetail } from "@/lib/queries/signals";
import { approveSignal, rejectSignal, submitSignalForReview, attachSignalEvidence } from "@/lib/actions/signals";
import { getSourceDocumentOptions } from "@/lib/queries/source-documents";
import { redirect } from "next/navigation";
import { SubmitButton } from "@/components/submit-button";
import { SourceDocumentPicker } from "@/components/source-document-picker";

async function submitForReviewAction(formData: FormData) {
  "use server";
  await submitSignalForReview(String(formData.get("signal_id")));
}

async function approveAction(formData: FormData) {
  "use server";
  await approveSignal({
    signal_id: String(formData.get("signal_id")),
    reviewer_notes: String(formData.get("reviewer_notes") || "") || undefined,
  });
}

async function rejectAction(formData: FormData) {
  "use server";
  await rejectSignal({
    signal_id: String(formData.get("signal_id")),
    rejection_reason: String(formData.get("rejection_reason") || "Rejected"),
  });
}

async function attachEvidenceAction(formData: FormData) {
  "use server";
  await attachSignalEvidence({
    signal_id: String(formData.get("signal_id") || ""),
    source_document_id: String(formData.get("source_document_id") || ""),
    evidence_type: String(formData.get("evidence_type") || "paraphrased_fact") as any,
    evidence_source_type: String(formData.get("evidence_source_type") || "human") as any,
    evidence_text: String(formData.get("evidence_text") || ""),
    citation_reference: String(formData.get("citation_reference") || ""),
  });
}

export default async function SignalDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [signal, sourceOptions] = await Promise.all([getSignalDetail(id), getSourceDocumentOptions()]);
  if (!signal) redirect("/app/signals");

  const defaultSourceId = signal.source_id ?? sourceOptions[0]?.source_id;
  const canAttachEvidence = ["draft", "in_review"].includes(signal.review_status);
  const canSubmitForReview = signal.review_status === "draft";
  const canAdminReview = signal.review_status === "in_review";

  return (
    <>
      <PageHeader
        title={signal.title}
        subtitle={`${signal.signal_type} · ${signal.jurisdiction ?? "-"} · created ${signal.created_at.slice(0, 10)}`}
        actions={
          <>
            <StatusBadge value={signal.review_status} />
            <DataClassBadge value={signal.data_class} />
            <ConfidenceBadge value={signal.confidence_level} />
          </>
        }
      />

      <div className="hv-body hv-stack">
        <div className="hv-card">
          <div className="hv-card-pad">
            <KV label="Summary" value={signal.summary} />
            <KV label="Evidence" value={<span className="hv-code">{signal.human_evidence_count}/{signal.evidence_count} human/total</span>} />
            <KV label="Entity" value={`${signal.entity_name ?? "-"} ${signal.entity_org ? `· ${signal.entity_org}` : ""}`} />
            <KV label="Source" value={signal.source_name ?? "-"} />
            <KV label="Internal notes" value={signal.internal_notes || "-"} />
            <KV label="Analyst notes" value={signal.analyst_notes || "-"} />
          </div>
        </div>

        <div className="hv-card">
          <div className="hv-card-pad">
            <div className="hv-section-head">
              <div className="hv-section-title">Evidence records</div>
            </div>
            <div className="hv-stack">
              {signal.evidence.map((e: any) => (
                <div key={e.id} className="hv-evidence-card">
                  <div className="hv-inline" style={{ justifyContent: "space-between" }}>
                    <div className="hv-inline">
                      <StatusBadge value={e.evidence_type} />
                      <StatusBadge value={e.evidence_source_type} />
                    </div>
                    <div className="hv-meta">{e.created_at.slice(0, 10)}</div>
                  </div>
                  <div style={{ margin: "10px 0" }}>{e.evidence_text}</div>
                  <div className="hv-meta">{e.citation_reference}</div>
                  {e.source_document_title || e.source_document_url ? (
                    <div className="hv-meta" style={{ marginTop: 8 }}>
                      Source document: {e.source_document_title ?? "Untitled"}
                      {e.source_document_publication_date ? ` · ${e.source_document_publication_date}` : ""}
                      {e.source_document_url ? ` · ${e.source_document_url}` : ""}
                    </div>
                  ) : null}
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="hv-grid hv-grid-2">
          <form action={attachEvidenceAction} className="hv-form-card hv-stack">
            <input type="hidden" name="signal_id" value={signal.id} />
            <div className="hv-card-title">Attach evidence</div>
            <div>
              Add another evidence record without recreating the signal. Approval still requires at least one human-verified evidence record.
            </div>

            {sourceOptions.length ? (
              <div className="hv-form-grid">
                <SourceDocumentPicker sources={sourceOptions} defaultSourceId={defaultSourceId} />
                <div>
                  <label className="hv-label">Evidence type</label>
                  <select name="evidence_type" defaultValue="supporting_context" disabled={!canAttachEvidence}>
                    <option>direct_quote</option>
                    <option>paraphrased_fact</option>
                    <option>date_confirmation</option>
                    <option>supporting_context</option>
                    <option>secondary_reference</option>
                  </select>
                </div>
                <div>
                  <label className="hv-label">Evidence source type</label>
                  <select name="evidence_source_type" defaultValue="human" disabled={!canAttachEvidence}>
                    <option>human</option>
                    <option>ai_assisted</option>
                  </select>
                </div>
                <div className="hv-field-full">
                  <label className="hv-label">Evidence text</label>
                  <textarea name="evidence_text" required disabled={!canAttachEvidence} />
                </div>
                <div className="hv-field-full">
                  <label className="hv-label">Citation reference</label>
                  <input
                    name="citation_reference"
                    required
                    disabled={!canAttachEvidence}
                    placeholder="page, section, paragraph or URL fragment"
                  />
                </div>
              </div>
            ) : (
              <div className="hv-note">No source documents are available yet. Add source documents first before attaching evidence.</div>
            )}

            {!canAttachEvidence ? (
              <div className="hv-note">
                Evidence can only be attached while the signal is in draft or in_review. Current status: <strong>{signal.review_status}</strong>
              </div>
            ) : null}

            <div className="hv-right">
              <SubmitButton className="hv-btn-primary" disabled={!canAttachEvidence || !sourceOptions.length}>
                Add evidence
              </SubmitButton>
            </div>
          </form>

          <div className="hv-stack">
            <form action={submitForReviewAction} className="hv-form-card hv-stack">
              <input type="hidden" name="signal_id" value={signal.id} />
              <div className="hv-card-title">Submit for review</div>
              <div>Use when evidence has been attached and the draft is ready for admin review.</div>
              {!canSubmitForReview ? (
                <div className="hv-note">Only draft signals can be submitted for review. Current status: <strong>{signal.review_status}</strong></div>
              ) : null}
              <SubmitButton className="hv-btn-primary" disabled={!canSubmitForReview}>Submit</SubmitButton>
            </form>

            <form action={approveAction} className="hv-form-card hv-stack">
              <input type="hidden" name="signal_id" value={signal.id} />
              <div className="hv-card-title">Approve</div>
              <textarea name="reviewer_notes" placeholder="Optional reviewer notes" disabled={!canAdminReview} />
              {!canAdminReview ? (
                <div className="hv-note">Only in_review signals can be approved. Current status: <strong>{signal.review_status}</strong></div>
              ) : null}
              <SubmitButton className="hv-btn-success" disabled={!canAdminReview}>Approve</SubmitButton>
            </form>

            <form action={rejectAction} className="hv-form-card hv-stack">
              <input type="hidden" name="signal_id" value={signal.id} />
              <div className="hv-card-title">Reject</div>
              <textarea name="rejection_reason" placeholder="Required rejection reason" required disabled={!canAdminReview} />
              {!canAdminReview ? (
                <div className="hv-note">Only in_review signals can be rejected. Current status: <strong>{signal.review_status}</strong></div>
              ) : null}
              <SubmitButton className="hv-btn-danger" disabled={!canAdminReview}>Reject</SubmitButton>
            </form>
          </div>
        </div>
      </div>
    </>
  );
}
