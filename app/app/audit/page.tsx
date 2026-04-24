import { PageHeader } from "@/components/ui";
import { getAuditEvents } from "@/lib/queries/audit";

export default async function AuditPage() {
  const rows = await getAuditEvents(80);
  return <><PageHeader title="Audit log" subtitle="Append-only operator history" /><div className="hv-body"><div className="hv-card"><div className="hv-card-pad">{rows.map((row:any)=><div key={row.id} className="hv-kv"><div><div className="hv-meta">{row.performed_at.slice(0,19).replace('T',' ')}</div><div className="hv-code">{row.action_type}</div></div><div><div className="hv-title-row">{row.change_summary ?? `${row.entity_type} ${row.entity_id}`}</div><div className="hv-meta">{row.performer_name ?? 'Unknown'} · {row.entity_type} · {row.from_status ?? '-'} → {row.to_status ?? '-'}</div></div></div>)}</div></div></div></>;
}
