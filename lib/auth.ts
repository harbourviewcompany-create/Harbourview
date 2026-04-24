// lib/auth.ts
// Harbourview Production Spine — auth helpers and role enforcement
// ADR-001 D1: requireRole throws if current user's platform_role is not in allowed list

import type { SupabaseClient } from "@supabase/supabase-js";

export type PlatformRole = "admin" | "analyst" | "client";

export type HarbourviewProfile = {
  id: string;
  email: string;
  full_name: string;
  platform_role: PlatformRole;
  default_workspace_id: string | null;
};

/**
 * Returns the current authenticated user's profile.
 * Throws if not authenticated.
 */
export async function getCurrentProfile(
  supabase: SupabaseClient
): Promise<HarbourviewProfile> {
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    throw new Error("Not authenticated");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id, email, full_name, platform_role, default_workspace_id")
    .eq("id", user.id)
    .single();

  if (profileError || !profile) {
    throw new Error("Profile not found");
  }

  return profile as HarbourviewProfile;
}

/**
 * Returns the current profile if their platform_role is in the allowed list.
 * Throws with a 403-appropriate error if role is insufficient.
 * Use this at the top of every server action that has access restrictions.
 *
 * Usage:
 *   const profile = await requireRole(supabase, ["admin"]);
 *   const profile = await requireRole(supabase, ["admin", "analyst"]);
 */
export async function requireRole(
  supabase: SupabaseClient,
  allowedRoles: PlatformRole[]
): Promise<HarbourviewProfile> {
  const profile = await getCurrentProfile(supabase);

  if (!allowedRoles.includes(profile.platform_role)) {
    throw new Error(
      `Insufficient permissions. Required: ${allowedRoles.join(" or ")}. ` +
        `Current role: ${profile.platform_role}`
    );
  }

  return profile;
}

/**
 * Returns true if the current user is an admin.
 */
export async function isAdmin(supabase: SupabaseClient): Promise<boolean> {
  try {
    const profile = await getCurrentProfile(supabase);
    return profile.platform_role === "admin";
  } catch {
    return false;
  }
}
