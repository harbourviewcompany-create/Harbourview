// app/auth/sign-in/route.ts
// Handles POST from login form. Signs in via Supabase Auth, sets session cookie.

import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@/lib/supabase/server";

export async function POST(request: NextRequest) {
  const formData = await request.formData();
  const email = formData.get("email") as string;
  const password = formData.get("password") as string;

  if (!email || !password) {
    return NextResponse.redirect(
      new URL("/login?error=Email+and+password+are+required", request.url),
      { status: 302 }
    );
  }

  const supabase = await createServerClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    return NextResponse.redirect(
      new URL(`/login?error=${encodeURIComponent(error.message)}`, request.url),
      { status: 302 }
    );
  }

  return NextResponse.redirect(new URL("/app", request.url), { status: 302 });
}
