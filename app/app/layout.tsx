import { AppShell } from "@/components/app-shell";
import { createServerClient } from "@/lib/supabase/server";
import { getCurrentProfile } from "@/lib/auth";
import { getDashboardStats } from "@/lib/queries/dashboard";

export default async function ProtectedLayout({ children }:{ children:React.ReactNode }) {
  const supabase = await createServerClient();
  const profile = await getCurrentProfile(supabase);
  const stats = await getDashboardStats();
  return <AppShell fullName={profile.full_name} role={profile.platform_role} pendingReview={stats.pendingReview}>{children}</AppShell>;
}
