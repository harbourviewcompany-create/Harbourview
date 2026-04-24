// Hardened Supabase Edge Function gateway for ChatGPT connector traffic.
// This function is intentionally fail-closed: every non-OPTIONS request requires an API key whose SHA-256 hash matches CHATGPT_CONNECTOR_API_KEY_SHA256.

const REQUIRED_ENV = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "CHATGPT_CONNECTOR_API_KEY_SHA256",
  "CHATGPT_CONNECTOR_ALLOWED_ORIGINS",
] as const;

function requireEnv(name: (typeof REQUIRED_ENV)[number]): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required env: ${name}`);
  return value;
}

function json(body: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      ...extraHeaders,
    },
  });
}

function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("origin") ?? "";
  const allowed = requireEnv("CHATGPT_CONNECTOR_ALLOWED_ORIGINS")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);

  if (!origin || !allowed.includes(origin)) return {};

  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "authorization,content-type,x-harbourview-api-key",
    "Access-Control-Max-Age": "600",
    "Vary": "Origin",
  };
}

function extractApiKey(request: Request): string | null {
  const explicit = request.headers.get("x-harbourview-api-key")?.trim();
  if (explicit) return explicit;

  const auth = request.headers.get("authorization")?.trim();
  if (auth?.toLowerCase().startsWith("bearer ")) return auth.slice(7).trim();

  return null;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function constantTimeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const max = Math.max(leftBytes.length, rightBytes.length, 64);
  let diff = leftBytes.length ^ rightBytes.length;

  for (let index = 0; index < max; index += 1) {
    diff |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }

  return diff === 0;
}

async function requireApiKey(request: Request): Promise<Response | null> {
  const key = extractApiKey(request);
  if (!key || key.length < 32 || key.length > 256) {
    return json({ error: "Unauthorized" }, 401, corsHeaders(request));
  }

  const expectedHash = requireEnv("CHATGPT_CONNECTOR_API_KEY_SHA256");
  const actualHash = await sha256Hex(key);

  if (!constantTimeEqual(actualHash, expectedHash)) {
    return json({ error: "Unauthorized" }, 401, corsHeaders(request));
  }

  return null;
}

async function handleHealth(request: Request): Promise<Response> {
  // Authenticated health check only. Do not expose environment details or secrets.
  requireEnv("SUPABASE_URL");
  requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  return json({ ok: true, service: "chatgpt-connector" }, 200, corsHeaders(request));
}

Deno.serve(async (request: Request) => {
  const headers = corsHeaders(request);

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }

  try {
    for (const envName of REQUIRED_ENV) requireEnv(envName);

    const authError = await requireApiKey(request);
    if (authError) return authError;

    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname.endsWith("/health")) {
      return await handleHealth(request);
    }

    return json({ error: "Not found" }, 404, headers);
  } catch (error) {
    console.error("chatgpt-connector error", error instanceof Error ? error.message : "unknown_error");
    return json({ error: "Connector unavailable" }, 503, headers);
  }
});
