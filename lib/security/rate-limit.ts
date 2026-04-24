import { getRedisEnv, hasRedisEnv } from "@/lib/security/env";

type RateLimitOptions = {
  limit: number;
  windowSeconds: number;
  namespace: string;
};

type RateLimitResult = {
  allowed: boolean;
  remaining: number;
  resetSeconds: number;
};

async function redisPipeline<T1, T2, T3>(commands: [unknown[], unknown[], unknown[]]): Promise<[T1, T2, T3]> {
  const env = getRedisEnv();
  const response = await fetch(`${env.redisRestUrl}/pipeline`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.redisRestToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(commands),
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("Rate limit backend unavailable");
  }

  const payload = (await response.json()) as Array<{ result?: unknown; error?: string }>;
  if (payload.some((item) => item.error)) {
    throw new Error("Rate limit backend command failed");
  }

  return [payload[0].result as T1, payload[1].result as T2, payload[2].result as T3];
}

function normalizeKeyPart(value: string): string {
  return value.replace(/[^a-zA-Z0-9:._-]/g, "_").slice(0, 160);
}

export async function checkRateLimit(identifier: string, options: RateLimitOptions): Promise<RateLimitResult> {
  if (!hasRedisEnv()) {
    if (process.env.NODE_ENV === "production") {
      throw new Error("Rate limit backend is required in production");
    }

    return { allowed: true, remaining: options.limit, resetSeconds: options.windowSeconds };
  }

  const key = `rl:${normalizeKeyPart(options.namespace)}:${normalizeKeyPart(identifier)}`;
  const [count, , ttl] = await redisPipeline<number, unknown, number>([
    ["INCR", key],
    ["EXPIRE", key, options.windowSeconds, "NX"],
    ["TTL", key],
  ]);

  const resetSeconds = ttl > 0 ? ttl : options.windowSeconds;
  const remaining = Math.max(options.limit - count, 0);

  return {
    allowed: count <= options.limit,
    remaining,
    resetSeconds,
  };
}

export function getClientIp(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const realIp = request.headers.get("x-real-ip")?.trim();
  return forwarded || realIp || "unknown";
}
