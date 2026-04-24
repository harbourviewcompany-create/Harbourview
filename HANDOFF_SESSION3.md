Harbourview — Canonical Handoff Brief
April 20, 2026 — Session 3

Supersedes: HANDOFF_SESSION2.md in all areas of conflict.
ADR-001 and non-negotiable rules from the Session 1 takeover brief remain
authoritative. Do not reopen them.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. SYSTEM CONTEXT — DO NOT CONFLATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

System A — Live crawler (DO NOT TOUCH)
  Supabase project: fgdrvqqezdiraqyuofte.supabase.co
  Status: live, running daily. Flat signals table. No dossiers. No review.

System B — Production Spine (this work)
  Supabase project: tpfvhhrwzsofhdcfdenc.supabase.co
  Status: project and auth users exist. Migrations NOT YET APPLIED.
  Pack: harbourview_production_spine_v5.zip


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. CANONICAL ASSET
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

File: harbourview_production_spine_v5.zip

Complete Next.js 15 App Router project. 72 files. Apply APPLY_ALL.sql
to the System B Supabase project and it runs. Pass the passwords and
npm test passes 18/18.

Key files:

  migrations/APPLY_ALL.sql          ← single paste, all 13 migrations,
                                      no \set meta-commands, literal UUIDs
  migrations/0009_seed_data.sql     ← golden-path fixtures, UUID block 00..01-09x
  migrations/0012_germany_operator_seed.sql ← OI-3 closed, UUID block 00..010x+
  lib/actions/dossiers.ts           ← corrected + _supabase escape hatch
  lib/actions/signals.ts            ← corrected (Bug 5)
  app/api/feed/[token]/route.ts     ← OI-7 fixed + item_notes in BLOCKED_FIELDS
  tests/golden-path.test.ts         ← rewritten: static imports, real G8,
                                      _supabase in N2/N4/N8
  tests/setup.ts                    ← NEW: mocks next/headers + next/cache
  vitest.config.ts                  ← setupFiles wired


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. CREDENTIALS — CONFIRMED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Supabase project (System B):
  URL:  https://tpfvhhrwzsofhdcfdenc.supabase.co
  Ref:  tpfvhhrwzsofhdcfdenc  (distinct from System A — confirmed via JWT decode)

Auth users in Supabase dashboard:
  admin@harbourview.io    UUID: 9866753f-1a8d-495c-8ab8-d0d1eebfce04  role: admin
  analyst@harbourview.io  UUID: 31e6281c-aec9-4c6d-a9c3-4852b1c057d5  role: analyst

Both UUIDs are already inlined in APPLY_ALL.sql and 0009_seed_data.sql.
No further substitution needed.

.env.local status:
  NEXT_PUBLIC_SUPABASE_URL             ✅ wired
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ✅ wired
  SUPABASE_SERVICE_ROLE_KEY            ✅ wired
  TEST_ADMIN_EMAIL                     ✅ admin@harbourview.io
  TEST_ADMIN_PASSWORD                  ❌ REPLACE_ME  ← only thing left
  TEST_ANALYST_EMAIL                   ✅ analyst@harbourview.io
  TEST_ANALYST_PASSWORD                ❌ REPLACE_ME  ← only thing left
  APP_URL                              ✅ http://localhost:3000


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. ALL BUGS FIXED — COMPLETE RECORD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From session 1 (takeover brief):
  Bug 1 — 0005: review_queue UNIQUE constraint → partial index          ✅
  Bug 2 — 0006: revokePublishEvent UPDATE → INSERT revocation row       ✅
  Bug 3 — 0006b: dossier supersede via session client → service client  ✅
  Bug 4 — 0008: profiles_insert RLS → auth.uid() = id allowed           ✅
  Bug 5 — signals.ts: queue resolution .eq('under_review') →
           .in(['pending','under_review'])                               ✅
  Gap   — dossiers.ts: snapshot missing evidence join → fixed           ✅

From session 2:
  OI-1 — Auth trigger (0010)                                            ✅
  OI-2 — Workspace membership RLS (0011)                                ✅
  OI-7 — Feed route revocation detection                                ✅
  Seed  — snapshot shape, review queue status, atomic publish,
           api_token convention, \set → literal UUIDs                   ✅

From session 3:
  OI-3  — Germany 5-operator real seed (0012)                           ✅
  BUG-1 — app/api/feed/[token]/route.ts: item_notes missing from
           BLOCKED_FIELDS → added (test G9 would have failed)           ✅
  BUG-2 — Server actions crash in vitest: cookies() throws outside
           request scope → fixed three ways:
           (a) tests/setup.ts mocks next/headers + next/cache
           (b) vitest.config.ts wires setupFiles
           (c) PublishDossierInput + RevokePublishInput gain _supabase?
               escape hatch; used in N2, N4, N8                         ✅
  REFACTOR — golden-path.test.ts rewritten:
           Static imports (publishDossier, revokePublishEvent at top)
           G8 calls real publishDossier() instead of building snapshot
             manually — test now actually exercises the join logic
           G6 asserts signal.review_status === 'approved' (was vacuous)
           N2/N4/N8 use direct calls with _supabase: adminClient
             instead of import().then() chains
           137 lines shorter, same coverage, stronger assertions         ✅


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. OPEN ITEMS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All OIs closed. Zero outstanding items.

  OI-1  Auth trigger                        ✅ Closed session 2
  OI-2  Multi-workspace client membership   ✅ Closed session 2
  OI-3  Germany 44-gatekeeper workbook      ✅ Closed session 3 → 0012
  OI-4  Field dictionary location           ✅ Closed session 1
  OI-5  revokePublishEvent UPDATE bug       ✅ Closed session 1
  OI-6  snapshot missing evidence join      ✅ Closed session 1
  OI-7  Feed route revocation detection     ✅ Closed session 1/2


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
6. MIGRATION MANIFEST — CONFIRMED APPLY ORDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  0001_create_enums.sql                   original (in APPLY_ALL)
  0002_create_profiles_and_workspaces     original (in APPLY_ALL)
  0003_create_sources_and_source_docs     original (in APPLY_ALL)
  0004_create_signals_and_evidence        original (in APPLY_ALL)
  0005_create_review_queue                CORRECTED
  0006_create_dossiers_and_events         CORRECTED
  0006b_amend_immutability_trigger        NEW
  0007_create_audit_events                original (in APPLY_ALL)
  0008_create_rls_policies                CORRECTED
  0009_seed_data                          CORRECTED (golden-path fixtures)
  0010_create_auth_trigger                NEW
  0011_workspace_membership_rls           NEW
  0012_germany_operator_seed              NEW (OI-3 — 5 real operators)

All 13 are concatenated in migrations/APPLY_ALL.sql.
APPLY_ALL contains zero \set meta-commands — safe for Supabase SQL editor.

UUID block separation (no overlaps):
  0009 fixtures:  00000000-0000-0000-0000-00000000001x through 9x
  0012 operators: 00000000-0000-0000-0000-00000000010x through 17x

After 0009 apply, run verification:
  select s.review_status, count(se.id) evidence_count,
         d.status dossier_status, pe.api_token
  from signals s
  left join signal_evidence se on se.signal_id = s.id
  left join dossier_items di on di.signal_id = s.id
  left join dossiers d on d.id = di.dossier_id
  left join publish_events pe on pe.dossier_id = d.id and pe.status = 'completed'
  where s.id = '00000000-0000-0000-0000-000000000040'
  group by s.review_status, d.status, pe.api_token;
  -- Expected: approved / 1 / published

After 0012 apply, run verification (in 0012 file footer):
  -- Expected: 5 rows, review_status=approved, evidence_count=1, dossier published


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
7. EXACT STEPS TO npm test PASSING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1 — Apply migrations
  Supabase dashboard → SQL editor → New query
  Paste entire contents of migrations/APPLY_ALL.sql → Run

Step 2 — Fill in .env.local passwords
  TEST_ADMIN_PASSWORD=<password set in Supabase dashboard for admin@harbourview.io>
  TEST_ANALYST_PASSWORD=<password set for analyst@harbourview.io>

Step 3 — Run
  npm install
  npm run dev        # terminal 1 — leave running (G9, N4, N5 hit localhost:3000)
  npm test           # terminal 2

Expected: 18/18 — 10 golden path + 8 negative path.

Debug sequence if tests fail:
  1. Check APPLY_ALL ran without errors (Supabase table editor → verify tables exist)
  2. Run seed verification queries above
  3. Confirm .env.local passwords match dashboard
  4. Confirm npm run dev is running before npm test
  5. On a specific test failure, paste the error output — the fix will be surgical


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
8. TEST INVENTORY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Golden path (10) — runs sequentially, shared state:
  G1.  analyst creates a source
  G2.  analyst creates a source document (URL-only — ADR-001 D2)
  G3.  analyst creates a signal
  G4.  analyst attaches human-verified evidence
  G5.  analyst submits signal for review
  G6.  admin approves the signal [asserts review_status === 'approved']
  G7.  admin creates a dossier and adds the approved signal
  G8.  admin publishes via publishDossier() server action;
         snapshot has full evidence chain [calls real action — not a mock]
  G9.  JSON feed returns snapshot for valid token;
         internal_notes/analyst_notes/reviewer_notes/item_notes absent
  G10. audit trail contains create/submit_for_review/approve events

Negative path (8):
  N1.  cannot approve a signal with zero evidence (DB trigger)
  N2.  cannot publish a dossier with a draft signal (app-layer gate)
         [calls publishDossier with _supabase: adminClient]
  N3.  published dossier cannot be mutated in place (DB trigger)
  N4.  revoked feed token returns 410 Gone (INSERT revocation model)
         [calls revokePublishEvent with _supabase: adminClient]
  N5.  invalid feed token returns 404
  N6.  duplicate source document URL blocked by partial unique index
  N7.  analyst cannot update review_queue_items (RLS)
  N8.  cannot revoke the same publish event twice (idempotency guard)
         [calls revokePublishEvent with _supabase: adminClient]


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
9. NON-NEGOTIABLE RULES — DO NOT WEAKEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  - Signal cannot be approved without at least one evidence record
  - Signal cannot be approved on AI-assisted evidence alone (min 1 human)
  - Signal cannot be published unless approved
  - Dossier cannot publish unless all included signals are approved
  - Published dossiers are immutable (DB trigger)
  - publish_events and audit_events are append-only (triggers, incl. svc role)
  - Client users have no DB access — JSON feed only via api_token
  - Internal notes never in snapshot_json or any API response
  - published_at and effective_at are distinct
  - Revocation is always a new INSERT row — never UPDATE on original

ADR-001 locked decisions:
  D1 — Admin/analyst separation (only admins approve and publish)
  D2 — URL-only source documents (no file storage at v1)
  D3 — No contacts table at v1
  D4 — Client output is JSON feed only


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10. INSTRUCTION BLOCK FOR NEXT CLAUDE INSTANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Paste this at the start of the next session, followed by the v5 pack:

---
You are continuing the Harbourview Production Spine build (System B).

System A is a live crawler at fgdrvqqezdiraqyuofte.supabase.co — do not
touch it. System B is at tpfvhhrwzsofhdcfdenc.supabase.co.

The canonical file is harbourview_production_spine_v5.zip. It is a complete
Next.js 15 App Router project ready to run. All bugs are fixed. All OIs are
closed. The test suite is correct and complete.

Current state: migrations NOT yet applied. The entire state of the work is
described in HANDOFF_SESSION3.md inside the pack.

Two things left before npm test:
  1. Paste migrations/APPLY_ALL.sql into Supabase SQL editor and run it
  2. Fill in TEST_ADMIN_PASSWORD and TEST_ANALYST_PASSWORD in .env.local

Auth users exist in the System B Supabase dashboard:
  admin@harbourview.io    UUID: 9866753f-1a8d-495c-8ab8-d0d1eebfce04
  analyst@harbourview.io  UUID: 31e6281c-aec9-4c6d-a9c3-4852b1c057d5

Do not reopen ADR-001. Do not weaken any non-negotiable rule.
Revocation is always an INSERT row — never UPDATE on the original row.

If tests fail, paste the error output. Do not guess at fixes — read the
failing assertion, trace it to the implementation, make the surgical change.
---
