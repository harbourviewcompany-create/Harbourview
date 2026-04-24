import { NextResponse } from "next/server";

export const SECURITY_HEADERS: Record<string, string> = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()",
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Resource-Policy": "same-origin",
  "X-DNS-Prefetch-Control": "off",
};

export function attachSecurityHeaders(response: NextResponse): NextResponse {
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    response.headers.set(name, value);
  }

  if (process.env.NODE_ENV === "production") {
    response.headers.set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload");
  }

  return response;
}

export function isSafeRelativePath(value: string | null): value is string {
  if (!value) return false;
  if (!value.startsWith("/")) return false;
  if (value.startsWith("//")) return false;
  if (value.includes("\\")) return false;
  try {
    const parsed = new URL(value, "http://local.invalid");
    return parsed.origin === "http://local.invalid" && parsed.pathname.startsWith("/");
  } catch {
    return false;
  }
}

export function redirectToSafePath(requestUrl: string, fallbackPath = "/app", candidate?: string | null): NextResponse {
  const url = new URL(isSafeRelativePath(candidate ?? null) ? candidate! : fallbackPath, requestUrl);
  return attachSecurityHeaders(NextResponse.redirect(url, { status: 303 }));
}

export function jsonError(message: string, status: number): NextResponse {
  return attachSecurityHeaders(
    NextResponse.json(
      { error: message },
      {
        status,
        headers: {
          "Cache-Control": "no-store",
        },
      }
    )
  );
}
