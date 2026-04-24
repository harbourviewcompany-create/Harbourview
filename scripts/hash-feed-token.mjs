#!/usr/bin/env node

import { createHash, randomBytes } from "node:crypto";

const provided = process.argv[2];
const token = provided && provided.trim().length > 0
  ? provided.trim()
  : `hv_feed_${randomBytes(32).toString("base64url")}`;

if (!/^[A-Za-z0-9._~-]{32,256}$/.test(token)) {
  console.error("Token must be 32-256 chars and contain only A-Z, a-z, 0-9, dot, underscore, tilde or hyphen.");
  process.exit(1);
}

const hash = createHash("sha256").update(token, "utf8").digest("hex");

console.log(JSON.stringify({ token, token_hash: hash }, null, 2));
console.error("Store only token_hash in Supabase. Send the raw token once through a secure channel, then discard it.");
