import { getScopedSupabase } from "@/lib/queries/_shared";

export async function getDashboardStats() {
  const { supabase } = await getScopedSupabase();
  const [approvedSignals, pendingReview, publishedDossiers, activeSources, recentApprovedSignals, workspaces] =
    await Promise.all([
      supabase.from("signals").select("id", { count: "exact", head: true }).eq("review_status", "approved"),
      supabase.from("review_queue_items").select("id", { count: "exact", head: true }).eq("status", "pending"),
      supabase.from("publish_events").select("id", { count: "exact", head: true }).eq("status", "published"),
      supabase.from("sources").select("id", { count: "exact", head: true }).eq("status", "active"),
      supabase
        .from("signals")
        .select("id", { count: "exact", head: true })
        .eq("review_status", "approved")
        .gte("reviewed_at", new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()),
      supabase.from("workspaces").select("id", { count: "exact", head: true }).eq("status", "active"),
    ]);

  return {
    approvedSignals: approvedSignals.count ?? 0,
    pendingReview: pendingReview.count ?? 0,
    publishedDossiers: publishedDossiers.count ?? 0,
    activeSources: activeSources.count ?? 0,
    recentApprovedSignals: recentApprovedSignals.count ?? 0,
    workspaces: workspaces.count ?? 0,
  };
}

export async function getRecentSignals(limit: number = 8) {
  const { supabase } = await getScopedSupabase();
  const { data } = await supabase
    .from("signals")
    .select("id, title, review_status, confidence_level, created_at, entity_name, entity_org")
    .order("created_at", { ascending: false })
    .limit(limit);
  return data ?? [];
}
