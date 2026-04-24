import { createHash, timingSafeEqual } from "crypto";

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function constantTimeEqualHex(leftHex: string, rightHex: string): boolean {
  const left = Buffer.from(leftHex, "hex");
  const right = Buffer.from(rightHex, "hex");

  if (left.length !== right.length) {
    const max = Math.max(left.length, right.length, 32);
    const paddedLeft = Buffer.concat([left, Buffer.alloc(Math.max(max - left.length, 0))]);
    const paddedRight = Buffer.concat([right, Buffer.alloc(Math.max(max - right.length, 0))]);
    timingSafeEqual(paddedLeft, paddedRight);
    return false;
  }

  return timingSafeEqual(left, right);
}

export function isValidBearerTokenShape(value: string): boolean {
  return /^[A-Za-z0-9._~-]{32,256}$/.test(value);
}
