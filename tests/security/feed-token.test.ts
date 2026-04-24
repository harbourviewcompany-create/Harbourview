import { describe, expect, it } from "vitest";
import { constantTimeEqualHex, isValidBearerTokenShape, sha256Hex } from "@/lib/security/tokens";
import { sanitizeFeedSnapshot } from "@/lib/feed/sanitize";

describe("public feed token security", () => {
  it("hashes tokens as sha256 hex", () => {
    const hash = sha256Hex("hv_live_test_token_1234567890_abcdefghijklmnopqrstuvwxyz");
    expect(hash).toMatch(/^[a-f0-9]{64}$/);
  });

  it("compares token hashes with constant-time helper semantics", () => {
    const token = "hv_live_test_token_1234567890_abcdefghijklmnopqrstuvwxyz";
    const hash = sha256Hex(token);
    expect(constantTimeEqualHex(hash, hash)).toBe(true);
    expect(constantTimeEqualHex(hash, sha256Hex(`${token}_wrong`))).toBe(false);
    expect(constantTimeEqualHex(hash, "abc")).toBe(false);
  });

  it("rejects malformed token shapes", () => {
    expect(isValidBearerTokenShape("short")).toBe(false);
    expect(isValidBearerTokenShape("contains space and punctuation!")).toBe(false);
    expect(isValidBearerTokenShape("a".repeat(257))).toBe(false);
    expect(isValidBearerTokenShape("A".repeat(32))).toBe(true);
  });

  it("recursively removes sensitive fields from feed snapshots", () => {
    const snapshot = {
      title: "Safe dossier",
      workspace_id: "hidden-workspace",
      internal_notes: "hidden",
      analyst_notes: "hidden",
      items: [
        {
          title: "Visible item",
          reviewer_notes: "hidden",
          private_metadata: { secret: "hidden" },
          nested: {
            evidence: "visible",
            token_hash: "hidden",
            source: { url: "https://example.com", api_key: "hidden" },
          },
        },
      ],
    };

    expect(sanitizeFeedSnapshot(snapshot)).toEqual({
      title: "Safe dossier",
      items: [
        {
          title: "Visible item",
          nested: {
            evidence: "visible",
            source: { url: "https://example.com" },
          },
        },
      ],
    });
  });
});
