import { createServerClient } from "@/lib/supabase/server";
import { getCurrentProfile } from "@/lib/auth";

export function toArray<T>(value: T | T[] | null | undefined): T[] {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

export async function getScopedSupabase() {
  const supabase = await createServerClient();
  const profile = await getCurrentProfile(supabase);
  return { supabase, profile };
}

export function normalizeLike(input: string | null | undefined): string | null {
  return input?.trim() ? `%${input.trim()}%` : null;
}
