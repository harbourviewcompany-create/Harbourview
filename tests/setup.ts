// tests/setup.ts
// Vitest setup — mocks Next.js server APIs unavailable in Node test context.
//
// Problem: server actions call createServerClient() → cookies() from next/headers.
// In vitest's Node environment, next/headers throws:
//   "cookies() was called outside a request scope"
// This breaks N2 (publishDossier), N4/N8 (revokePublishEvent) which call
// server actions directly via dynamic import.
//
// Solution: mock next/headers with a no-op implementation before any test runs.
// The server actions that use cookies() are testing business logic, not the
// cookie layer — so a silent no-op is correct here.
//
// next/cache revalidatePath() is also mocked — it's a no-op in test context.

import { vi } from "vitest";

// --- next/headers mock ---
// cookies() returns a ReadonlyRequestCookies-compatible object with no stored cookies.
// Server clients initialised in test context will have no session — which is fine
// because the affected tests (N2, N4, N8) import server actions that use the
// Supabase auth context from the _testClient override (see note below).
vi.mock("next/headers", () => ({
  cookies: vi.fn(() => ({
    getAll: () => [],
    set: () => {},
    delete: () => {},
    has: () => false,
    get: () => undefined,
  })),
  headers: vi.fn(() => new Headers()),
}));

// --- next/cache mock ---
vi.mock("next/cache", () => ({
  revalidatePath: vi.fn(),
  revalidateTag: vi.fn(),
}));
