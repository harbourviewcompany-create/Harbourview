import { PageHeader, StatusBadge, DataClassBadge, ConfidenceBadge, ButtonLink } from "@/components/ui";
import { getReviewQueue } from "@/lib/queries/review";

export default async function ReviewPage() {
  const rows = await getReviewQueue();
  return <><PageHeader title="Review queue" subtitle={`${rows.length} item(s) awaiting admin handling`} /><div className="hv-body"><div className="hv-stack">{rows.map((row:any)=><div key={row.id} className="hv-card"><div className="hv-card-pad"><div className="hv-section-head"><div><div className="hv-title-row">{row.signal_title}</div><div className="hv-meta">{row.jurisdiction ?? "-"} · {row.signal_type ?? "-"} · submitted {row.created_at.slice(0,10)}</div></div><div className="hv-inline"><StatusBadge value={row.status} /><DataClassBadge value={row.data_class} /><ConfidenceBadge value={row.confidence_level} /></div></div><div style={{ color:'var(--text-secondary)', marginBottom:12 }}>{row.signal_summary}</div><div className="hv-note" style={{ marginBottom:12 }}><div className="hv-card-title">Evidence gate</div><div>Human-verified evidence: <span className="hv-code">{row.human_evidence_count}</span> · Total evidence: <span className="hv-code">{row.evidence_count}</span></div></div><div className="hv-right"><ButtonLink href={`/app/signals/${row.signal_id}`} variant="ghost">Open signal</ButtonLink></div></div></div>)}</div></div></>;
}
