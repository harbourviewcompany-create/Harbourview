type Bucket = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, Bucket>();

export function isRateLimited(key: string, options: { limit: number; windowMs: number }): boolean {
  const now = Date.now();
  const current = buckets.get(key);

  if (!current || current.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + options.windowMs });
    return false;
  }

  current.count += 1;
  return current.count > options.limit;
}

export function getClientIp(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const realIp = request.headers.get("x-real-ip")?.trim();
  return forwarded || realIp || "unknown";
}
