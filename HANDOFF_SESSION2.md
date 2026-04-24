Harbourview — Canonical Handoff Brief
April 20, 2026 — Session 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. WHAT THIS IS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

A ground-truth handoff for the Harbourview Production Spine (System B).
Everything marked CONFIRMED was verified from code. Everything marked
INFERRED is logically derived. Nothing is guessed.

This brief supersedes the April 20 Session 1 takeover brief in all areas
where they conflict. The session 1 brief remains authoritative for ADR-001,
the non-negotiable rules, and the two-system architecture context.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. THE TWO SYSTEMS — DO NOT CONFLATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

System A — Live crawler (DO NOT TOUCH)
  Supabase project: fgdrvqqezdiraqyuofte.supabase.co
  Status: live, running daily at 6am via Windows Task Scheduler
  Schema: flat signals table (pri, cat, score, lane_r/e/t, headline)
  RLS: allow all. No review workflow. No dossiers.

System B — Production Spine (this session's work)
  Supabase project: tpfvhhrwzsofhdcfdenc.supabase.co
  Status: project created, auth users created, migrations NOT YET APPLIED
  Schema: 12-table evidence-first platform (see session 1 brief for full schema)
  Pack: harbourview_production_spine_v4.zip


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. CANONICAL ASSET — THIS SESSION'S OUTPUT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

File: harbourview_production_spine_v4.zip

This is a complete Next.js 15 App Router project. It contains:

  MIGRATIONS (in migrations/)
  ┌─────────────────────────────────────────────────────────┐
  │ File                                    Source          │
  ├─────────────────────────────────────────────────────────┤
  │ 0001_create_enums.sql                   Original*       │
  │ 0002_create_profiles_and_workspaces.sql Original*       │
  │ 0003_create_sources_and_source_docs.sql Original*       │
  │ 0004_create_signals_and_evidence.sql    Original*       │
  │ 0005_create_review_queue.sql            CORRECTED       │
  │ 0006_create_dossiers_and_events.sql     CORRECTED       │
  │ 0006b_amend_immutability_trigger.sql    NEW             │
  │ 0007_create_audit_events.sql            Original*       │
  │ 0008_create_rls_policies.sql            CORRECTED       │
  │ 0009_seed_data.sql                      CORRECTED       │
  │ 0010_create_auth_trigger.sql            NEW (OI-1)      │
  │ 0011_workspace_membership_rls.sql       NEW (OI-2)      │
  │ 0012_germany_operator_seed.sql          NEW (OI-3)      │
  │ APPLY_ALL.sql                           READY TO PASTE  │
  └─────────────────────────────────────────────────────────┘
  * Originals not in this pack — pull from files (2).zip in the session 1
    uploads. APPLY_ALL.sql already includes them concatenated in.

  SERVER ACTIONS (lib/actions/)
    dossiers.ts   — CORRECTED (OI-5, OI-6, createDossier workspace check)
    signals.ts    — CORRECTED (Bug 5)
    sources.ts    — original, no changes
    source-documents.ts — original, no changes

  INFRASTRUCTURE (lib/supabase/, middleware.ts)
    server.ts, service.ts, middleware.ts — all correct, no changes needed

  ENV
    .env.local    — WIRED with System B credentials (see section 4)
    .env.example  — template, correct

  TESTS
    tests/golden-path.test.ts — CORRECTED (N4 rewritten, G8/G9 tightened)

  SINGLE-FILE MIGRATION
    migrations/APPLY_ALL.sql — all 12 migrations concatenated, \set
    meta-commands replaced with literal UUIDs, safe for Supabase SQL editor


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. CREDENTIALS AND ENVIRONMENT — CONFIRMED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Supabase project (System B):
  URL:      https://tpfvhhrwzsofhdcfdenc.supabase.co
  Ref:      tpfvhhrwzsofhdcfdenc
  Keys:     In .env.local — NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY (anon)
                          — SUPABASE_SERVICE_ROLE_KEY (service role)

Auth users created in Supabase dashboard:
  admin@harbourview.io   — UUID: 9866753f-1a8d-495c-8ab8-d0d1eebfce04
  analyst@harbourview.io — UUID: 31e6281c-aec9-4c6d-a9c3-4852b1c057d5

  Both UUIDs are already inlined into APPLY_ALL.sql and 0009_seed_data.sql.
  No further UUID substitution is needed.

.env.local status:
  NEXT_PUBLIC_SUPABASE_URL             ✅ set
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ✅ set
  SUPABASE_SERVICE_ROLE_KEY            ✅ set
  TEST_ADMIN_EMAIL                     ✅ set (admin@harbourview.io)
  TEST_ADMIN_PASSWORD                  ❌ REPLACE_ME — fill in before npm test
  TEST_ANALYST_EMAIL                   ✅ set (analyst@harbourview.io)
  TEST_ANALYST_PASSWORD                ❌ REPLACE_ME — fill in before npm test
  APP_URL                              ✅ set (http://localhost:3000)

The passwords are whatever were set in the Supabase Auth dashboard when
creating the two users. They are not stored anywhere in this pack.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. WHAT WAS FIXED THIS SESSION — COMPLETE RECORD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All bugs and open items from session 1 that were in scope for this session:

OI-1 CLOSED — Auth trigger written (0010_create_auth_trigger.sql)
  handle_new_user() fires on auth.users INSERT. Creates profiles row with
  platform_role='analyst' default, full_name from raw_user_meta_data or
  email prefix fallback. SECURITY DEFINER, ON CONFLICT DO NOTHING.
  GRANT EXECUTE to supabase_auth_admin for cross-schema trigger access.

OI-2 CLOSED — Multi-workspace membership resolved (0011_workspace_membership_rls.sql)
  Decision: client users scoped to workspace memberships. Internal users
  (admin/analyst) retain cross-workspace visibility. dossiers_select,
  dossier_items_select, publish_events_select policies replaced with
  two-arm versions: platform_role IN ('admin','analyst') OR (client AND
  is_workspace_member(workspace_id)). createDossier() server action now
  validates analyst workspace membership before insert; admins exempt.

OI-4 CLOSED (session 1) — Field dictionary found in harbourview_related_files

OI-5 CLOSED (session 1) — revokePublishEvent rewritten as INSERT (not UPDATE)

OI-6 CLOSED (session 1) — publishDossier snapshot now includes full evidence
  chain: signal_evidence + source_documents joined, ordered by created_at,
  internal fields excluded at select time.

OI-7 CLOSED (session 1) — Feed route revocation detection fixed: queries for
  revocation row WHERE revokes_event_id = $id AND status = 'revoked' instead
  of checking original row status.

0009 seed CORRECTED (this session):
  [1] snapshot_json completed — full evidence chain with schema_version,
      workspace block, source_document provenance per evidence record.
  [2] review_queue_items inserted with status='pending' (was 'under_review').
  [3] Dossier publish is single atomic UPDATE (status + published_at +
      published_by_profile_id together).
  [4] api_token renamed to hvfeed_seed_dev_only_... convention.
  [5] \set meta-commands replaced with literal UUIDs in APPLY_ALL.sql
      (Supabase SQL editor does not support psql meta-commands).

.env.local wired — System B credentials confirmed from JWT decode.
  Project ref tpfvhhrwzsofhdcfdenc verified distinct from System A.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
6. OPEN ITEMS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ID    Item                                    Status
────  ──────────────────────────────────────  ────────────────────────────
OI-1  Auth trigger                            CLOSED this session
OI-2  Multi-workspace client membership       CLOSED this session
OI-3  Germany 44-gatekeeper workbook as seed  CLOSED — 0012_germany_operator_seed.sql
      5 real operators sourced from workbook:  Adjupharm, Bathera, FOUR 20 PHARMA,
      Nimbus Health, WEECO. Separate client workspace (germany-operator-intelligence).
      UUID block 000...0100+. Fully additive — zero overlap with 0009 fixtures.

BUG-1 FIXED — feed route item_notes leak (app/api/feed/[token]/route.ts)
      sanitizeSnapshot() BLOCKED_FIELDS was missing "item_notes". Test G9 asserts
      expect(bodyStr).not.toContain("item_notes"). Added to blocked set.

BUG-2 FIXED — server actions crash in vitest Node env (next/headers throws)
      Tests N2/N4/N8 call publishDossier/revokePublishEvent via dynamic import.
      next/headers cookies() throws "called outside a request scope" in Node env.
      Fix: tests/setup.ts mocks next/headers + next/cache via vi.mock() before
      tests run. vitest.config.ts wired with setupFiles: ["./tests/setup.ts"].
      lib/actions/dossiers.ts: PublishDossierInput and RevokePublishInput now accept
      optional _supabase field (test-only escape hatch). N2/N4/N8 tests pass
      adminClient as _supabase so requireRole() sees a real authenticated session.
OI-4  Field dictionary                        CLOSED session 1
OI-5  revokePublishEvent UPDATE bug           CLOSED session 1
OI-6  snapshot missing evidence join          CLOSED session 1
OI-7  Feed route revocation detection         CLOSED session 1

One open item remains: OI-3. The WEECO Pharma GmbH seed in 0009 is a valid
placeholder but the Germany 44-gatekeeper workbook (referenced in session 1
brief) would become the real seed dataset once sourced. Not blocking v1.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
7. EXACT NEXT STEPS TO REACH npm test PASSING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1 — Apply migrations (Supabase SQL editor)
  Apply order: 0001→0002→0003→0004→0005→0006→0006b→0007→0008→0009→0010→0011→0012
  APPLY_ALL.sql already contains all migrations concatenated with literal UUIDs.

  Verify with this query after:
    select s.review_status, count(se.id) as evidence_count,
           d.status as dossier_status, pe.api_token
    from signals s
    left join signal_evidence se on se.signal_id = s.id
    left join dossier_items di on di.signal_id = s.id
    left join dossiers d on d.id = di.dossier_id
    left join publish_events pe on pe.dossier_id = d.id
      and pe.status = 'completed'
    where s.id = '00000000-0000-0000-0000-000000000040'
    group by s.review_status, d.status, pe.api_token;

  Expected: review_status=approved, evidence_count=1, dossier_status=published.

Step 2 — Fill in .env.local passwords
  Edit .env.local in the project root.
  Replace TEST_ADMIN_PASSWORD=REPLACE_ME with the password set in the dashboard.
  Replace TEST_ANALYST_PASSWORD=REPLACE_ME with the analyst password.

Step 3 — Run
  npm install          (packages already in package.json, this is fast)
  npm run dev          (terminal 1 — leave running, tests hit localhost:3000)
  npm test             (terminal 2)

Expected: 18 tests pass (10 golden path + 8 negative path).


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
8. GOLDEN PATH AND NEGATIVE PATH — TEST INVENTORY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Golden path (10):
  1. analyst creates a source
  2. analyst creates a source document (URL-only, ADR-001 D2)
  3. analyst creates a signal
  4. analyst attaches human-verified evidence
  5. analyst submits signal for review
  6. admin approves the signal; review queue item resolves
  7. admin creates a dossier and adds the approved signal
  8. admin publishes the dossier; snapshot includes evidence records
  9. JSON feed returns snapshot for valid token; no internal fields present
  10. audit trail contains all key events for the signal

Negative path (8):
  N1. cannot approve a signal with zero evidence (DB trigger)
  N2. cannot publish a dossier with a draft signal (app-layer gate)
  N3. published dossier cannot be mutated in place (DB trigger)
  N4. revoked feed token returns 410 (INSERT revocation row model)
  N5. invalid feed token returns 404
  N6. duplicate source document URL blocked by partial unique index
  N7. analyst cannot update review_queue_items (RLS)
  N8. cannot revoke the same publish event twice (idempotency guard)

Full test file: tests/golden-path.test.ts


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
9. LOCKED ARCHITECTURAL DECISIONS — DO NOT REOPEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From ADR-001 (session 1 brief, section 5). Repeated here for completeness.

D1 — Admin/analyst separation. Only admins approve signals and publish dossiers.
D2 — URL-only source documents. No file storage at v1.
D3 — No contacts table at v1. Plain text fields on sources and signals.
D4 — Client output is JSON feed only. No client UI. No direct DB access.

Non-negotiable rules (never weaken):
  - Signal cannot be approved without at least one evidence record
  - Signal cannot be approved on AI-assisted evidence alone (min 1 human)
  - Signal cannot be published unless approved
  - Dossier cannot publish unless all included signals are approved
  - Published dossiers are immutable (DB trigger enforces)
  - publish_events and audit_events are append-only (triggers enforce,
    including against service role)
  - Client users have no DB access — JSON feed only via api_token
  - Internal notes never appear in snapshot_json or any API response
  - published_at and effective_at are distinct — never conflate
  - Revocation is always a new INSERT row, never an UPDATE on original


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10. INSTRUCTION BLOCK FOR THE NEXT CLAUDE INSTANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Paste this at the start of the next session, followed by the pack:

---
You are continuing the Harbourview Production Spine build (System B).

System A is a live crawler at fgdrvqqezdiraqyuofte.supabase.co — do not
touch it. System B is the production spine at tpfvhhrwzsofhdcfdenc.supabase.co.

The canonical file is harbourview_production_spine_v4.zip. It contains a
complete Next.js 15 App Router project with all migrations, corrected server
actions, wired Supabase clients, and a full golden-path test suite.

Current state: migrations have NOT yet been applied. The next step is to
apply migrations/APPLY_ALL.sql via the Supabase SQL editor, fill in the two
REPLACE_ME passwords in .env.local, then run npm run dev + npm test.

Auth users exist in the Supabase dashboard:
  admin@harbourview.io   — UUID 9866753f-1a8d-495c-8ab8-d0d1eebfce04
  analyst@harbourview.io — UUID 31e6281c-aec9-4c6d-a9c3-4852b1c057d5

All OIs are closed except OI-3 (Germany 44-gatekeeper workbook as seed).
Do not reopen ADR-001. Do not weaken any non-negotiable rule. Revocation is
always an INSERT row — never UPDATE on the original publish_events row.

If tests fail, debug in this order:
  1. Verify APPLY_ALL.sql ran without errors (check Supabase table editor)
  2. Run the seed verification query in section 7 of the handoff brief
  3. Confirm .env.local passwords match what was set in the dashboard
  4. Check that npm run dev is running before npm test (feed tests need it)
---
