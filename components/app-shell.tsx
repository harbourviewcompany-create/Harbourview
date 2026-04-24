"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
export function AppShell({ children, fullName, role, pendingReview }:{ children:React.ReactNode; fullName:string; role:string; pendingReview:number; }) {
  const pathname = usePathname();
  const NAV = [
    { section: "Workspace", items: [{ href: "/app", label: "Overview" }] },
    { section: "Intelligence", items: [{ href: "/app/sources", label: "Sources" }, { href: "/app/signals", label: "Signals" }] },
    { section: "Operations", items: [{ href: "/app/review", label: "Review queue", badge: pendingReview }, { href: "/app/dossiers", label: "Dossiers" }, { href: "/app/publish", label: "Publish preview" }, { href: "/app/audit", label: "Audit log" }] },
  ];
  return <div className="hv-root"><aside className="hv-sidebar"><div className="hv-logo"><span className="hv-logo-mark">Harbourview</span><span className="hv-logo-sub">Intelligence Platform</span></div>{NAV.map(group => <div key={group.section}><div className="hv-nav-section">{group.section}</div><ul className="hv-nav-list">{group.items.map(item => { const active = item.href === "/app" ? pathname === "/app" : pathname.startsWith(item.href); return <li className={`hv-nav-item ${active ? "active" : ""}`} key={item.href}><Link href={item.href}><span>{item.label}</span>{item.badge ? <span className="hv-nav-badge">{item.badge}</span> : null}</Link></li>; })}</ul></div>)}<div className="hv-sidebar-footer"><div style={{ fontSize:12, fontWeight:500 }}>{fullName}</div><div className="hv-page-subtitle" style={{ marginTop:2 }}>{role}</div><form action="/auth/sign-out" method="POST" style={{ marginTop:12 }}><button className="hv-btn hv-btn-ghost hv-btn-sm" type="submit">Sign out</button></form></div></aside><main className="hv-main">{children}</main></div>;
}
