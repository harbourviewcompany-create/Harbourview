import { redirect } from "next/navigation";
import { PageHeader } from "@/components/ui";
import { SubmitButton } from "@/components/submit-button";
import { SourceDocumentPicker } from "@/components/source-document-picker";
import {
  createSignal,
  attachSignalEvidence,
  submitSignalForReview,
} from "@/lib/actions/signals";
import { getSourceDocumentOptions } from "@/lib/queries/source-documents";

async function createSignalAction(formData: FormData) {
  "use server";

  const sourceId = String(formData.get("source_id") || "").trim();
  const sourceDocumentId = String(formData.get("source_document_id") || "").trim();

  if (!sourceId) {
    throw new Error("A source must be selected.");
  }

  if (!sourceDocumentId) {
    throw new Error("A source document must be selected.");
  }

  const signal = await createSignal({
    title: String(formData.get("title") ?? ""),
    summary: String(formData.get("summary") ?? ""),
    signal_type: String(formData.get("signal_type") ?? ""),
    jurisdiction: String(formData.get("jurisdiction") || "") || undefined,
    event_date: String(formData.get("event_date") || "") || undefined,
    entity_name: String(formData.get("entity_name") || "") || undefined,
    entity_org: String(formData.get("entity_org") || "") || undefined,
    data_class: String(formData.get("data_class") ?? "observed") as any,
    confidence_level: String(formData.get("confidence_level") ?? "low") as any,
    visibility_scope: String(formData.get("visibility_scope") ?? "internal") as any,
    source_id: sourceId,
    internal_notes: String(formData.get("internal_notes") || "") || undefined,
    analyst_notes: String(formData.get("analyst_notes") || "") || undefined,
  });

  await attachSignalEvidence({
    signal_id: signal.id,
    source_document_id: sourceDocumentId,
    evidence_type: String(formData.get("evidence_type") ?? "paraphrased_fact") as any,
    evidence_source_type: String(formData.get("evidence_source_type") ?? "human") as any,
    evidence_text: String(formData.get("evidence_text") ?? ""),
    citation_reference: String(formData.get("citation_reference") ?? ""),
  });

  if (formData.get("submit_for_review") === "yes") {
    await submitSignalForReview(signal.id);
  }

  redirect(`/app/signals/${signal.id}`);
}

export default async function NewSignalPage() {
  const sourceOptions = await getSourceDocumentOptions();
  const defaultSourceId = sourceOptions[0]?.source_id;

  return (
    <>
      <PageHeader
        title="New signal"
        subtitle="Create signal, attach minimum evidence and optionally submit for review"
      />
      <div className="hv-body">
        <form action={createSignalAction} className="hv-form-card hv-stack">
          <div className="hv-form-grid">
            <div>
              <label className="hv-label">Title</label>
              <input name="title" required />
            </div>
            <div>
              <label className="hv-label">Signal type</label>
              <select name="signal_type" defaultValue="licensing_update">
                <option>licensing_update</option>
                <option>market_entry</option>
                <option>regulatory_change</option>
                <option>market_consolidation</option>
                <option>investment</option>
                <option>personnel_change</option>
              </select>
            </div>
            <div className="hv-field-full">
              <label className="hv-label">Summary</label>
              <textarea name="summary" required />
            </div>
            <div>
              <label className="hv-label">Jurisdiction</label>
              <select name="jurisdiction" defaultValue="DE">
                <option>DE</option>
                <option>NL</option>
                <option>UK</option>
                <option>PL</option>
                <option>PT</option>
              </select>
            </div>
            <div>
              <label className="hv-label">Event date</label>
              <input type="date" name="event_date" />
            </div>
            <div>
              <label className="hv-label">Data class</label>
              <select name="data_class" defaultValue="observed">
                <option>observed</option>
                <option>derived</option>
                <option>inferred</option>
                <option>unverified</option>
              </select>
            </div>
            <div>
              <label className="hv-label">Confidence level</label>
              <select name="confidence_level" defaultValue="high">
                <option>low</option>
                <option>medium</option>
                <option>high</option>
                <option>confirmed</option>
              </select>
            </div>
            <div>
              <label className="hv-label">Entity name</label>
              <input name="entity_name" />
            </div>
            <div>
              <label className="hv-label">Entity org</label>
              <input name="entity_org" />
            </div>
            <SourceDocumentPicker sources={sourceOptions} defaultSourceId={defaultSourceId} />
            <div>
              <label className="hv-label">Visibility</label>
              <select name="visibility_scope" defaultValue="internal">
                <option>internal</option>
                <option>workspace</option>
              </select>
            </div>
            <div className="hv-field-full">
              <label className="hv-label">Internal notes</label>
              <textarea name="internal_notes" />
            </div>
            <div className="hv-field-full">
              <label className="hv-label">Analyst notes</label>
              <textarea name="analyst_notes" />
            </div>
          </div>

          <hr className="hv-divider" />

          <div className="hv-note">
            <div className="hv-card-title">Evidence gate</div>
            <div>
              At least one evidence record is required. Human-verified evidence is required for approval.
            </div>
          </div>

          <div className="hv-form-grid">
            <div>
              <label className="hv-label">Evidence type</label>
              <select name="evidence_type" defaultValue="paraphrased_fact">
                <option>direct_quote</option>
                <option>paraphrased_fact</option>
                <option>date_confirmation</option>
                <option>supporting_context</option>
                <option>secondary_reference</option>
              </select>
            </div>
            <div>
              <label className="hv-label">Evidence source type</label>
              <select name="evidence_source_type" defaultValue="human">
                <option>human</option>
                <option>ai_assisted</option>
              </select>
            </div>
            <div className="hv-field-full">
              <label className="hv-label">Evidence text</label>
              <textarea name="evidence_text" required />
            </div>
            <div className="hv-field-full">
              <label className="hv-label">Citation reference</label>
              <input name="citation_reference" required placeholder="page, section or URL fragment" />
            </div>
            <div>
              <label className="hv-label">Submit to review now</label>
              <select name="submit_for_review" defaultValue="yes">
                <option value="yes">yes</option>
                <option value="no">no</option>
              </select>
            </div>
          </div>

          <div className="hv-right">
            <a className="hv-btn hv-btn-ghost" href="/app/signals">
              Cancel
            </a>
            <SubmitButton className="hv-btn-primary">Create signal</SubmitButton>
          </div>
        </form>
      </div>
    </>
  );
}
