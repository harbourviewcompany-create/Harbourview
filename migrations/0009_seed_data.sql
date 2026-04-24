-- 0009_seed_data.sql (corrected)
-- Harbourview Production Spine — pressure-test seed data
-- Germany market / WEECO Pharma GmbH anchor
--
-- CORRECTIONS vs prior version:
--
-- [1] snapshot_json COMPLETED
--   Prior version had a minimal snapshot missing evidence records and
--   source_document provenance. Corrected to match the full shape output
--   by publishDossier() (lib/actions/dossiers.ts, corrected version):
--   schema_version, evidence array with source_document nested per signal.
--
-- [2] review_queue_items status CHANGED to 'pending'
--   Prior version inserted with status = 'under_review'. The corrected
--   server action (approveSignal/rejectSignal) targets both 'pending' and
--   'under_review', but the canonical insert status from submitSignalForReview
--   is 'pending'. Using 'pending' here keeps the seed consistent with the
--   corrected server action flow so golden-path test step 5 runs cleanly.
--
-- [3] Dossier publish update SINGLE statement
--   Prior version had: UPDATE set status='ready_for_publish', then
--   UPDATE set status='published', published_at, published_by_profile_id.
--   The block_published_dossier_mutation() trigger fires on any update once
--   status = 'published'. The transition ready_for_publish → published is
--   safe (trigger only blocks when OLD.status = 'published'), but using a
--   single atomic publish statement (status + published_at + published_by
--   together) matches the publishDossier() server action pattern exactly.
--
-- [4] api_token renamed to dev-only convention
--   Uses 'hvfeed_seed_dev_only_00000000000000000000000000000090' to make
--   it obvious this token is non-production and should be rotated before
--   any integration test that touches the feed route.
--
-- ============================================================
-- HOW TO USE THIS FILE
-- ============================================================
--
-- Step 1: Create admin and analyst users in Supabase Auth dashboard
--   (or via: supabase auth admin --create-user --email ... --password ...)
--
-- Step 2: Copy the resulting auth.users UUIDs into the \set block below:
--
--   \set admin_id    '<paste-uuid-from-auth-dashboard>'
--   \set analyst_id  '<paste-uuid-from-auth-dashboard>'
--
-- Step 3: Apply all migrations in order, including this file last:
--   0001 → 0002 → 0003 → 0004 → 0005 → 0006 → 0006b → 0007 → 0008 → 0009 → 0010 → 0011
--
-- Step 4: For the golden-path test suite, set env vars:
--   TEST_ADMIN_EMAIL=admin@harbourview.io
--   TEST_ADMIN_PASSWORD=<password-set-in-auth-dashboard>
--   TEST_ANALYST_EMAIL=analyst@harbourview.io
--   TEST_ANALYST_PASSWORD=<password-set-in-auth-dashboard>
--
-- NOTE: 0010_create_auth_trigger.sql fires on auth.users INSERT and creates
-- the profiles row automatically. If you apply 0010 BEFORE creating auth users,
-- profiles will be created by the trigger automatically — no manual profile
-- insert needed, and the INSERT below will hit the ON CONFLICT DO NOTHING guard.
-- If you apply migrations first and create users after, the trigger handles it.
-- Either order is safe.
--
-- NOTE: This seed is dev/test only. Do NOT apply to production.
-- The api_token in this file is a fixed placeholder — rotate before any
-- production use of the feed route.
--
-- ============================================================

-- ============================================================
-- Replace these two UUIDs with actual auth.users IDs before running
-- ============================================================
\set admin_id    '9866753f-1a8d-495c-8ab8-d0d1eebfce04'
\set analyst_id  '31e6281c-aec9-4c6d-a9c3-4852b1c057d5'

-- Fixed UUIDs for deterministic test references (do not change)
\set workspace_id '00000000-0000-0000-0000-000000000010'
\set source_id    '00000000-0000-0000-0000-000000000020'
\set doc_id       '00000000-0000-0000-0000-000000000030'
\set signal_id    '00000000-0000-0000-0000-000000000040'
\set evidence_id  '00000000-0000-0000-0000-000000000050'
\set rq_id        '00000000-0000-0000-0000-000000000060'
\set dossier_id   '00000000-0000-0000-0000-000000000070'
\set di_id        '00000000-0000-0000-0000-000000000080'
\set pe_id        '00000000-0000-0000-0000-000000000090'

-- ============================================================
-- Profiles
-- NOTE: if 0010_create_auth_trigger.sql was applied before auth user
-- creation, the trigger already created these rows. The ON CONFLICT
-- guard makes this idempotent. The UPDATE corrects full_name and
-- platform_role in case the trigger used defaults.
-- ============================================================
insert into profiles (id, email, full_name, platform_role) values
  (:'admin_id',   'admin@harbourview.io',   'HV Admin',    'admin'),
  (:'analyst_id', 'analyst@harbourview.io', 'HV Analyst',  'analyst')
on conflict (id) do update set
  full_name     = excluded.full_name,
  platform_role = excluded.platform_role;

-- ============================================================
-- Internal workspace
-- ============================================================
insert into workspaces (id, name, slug, is_internal, created_by_profile_id) values
  (:'workspace_id', 'Germany Intelligence', 'germany-intelligence', true, :'admin_id')
on conflict (id) do nothing;

-- ============================================================
-- Workspace members
-- ============================================================
insert into workspace_members (workspace_id, profile_id, workspace_role, added_by_profile_id) values
  (:'workspace_id', :'admin_id',   'owner',  :'admin_id'),
  (:'workspace_id', :'analyst_id', 'editor', :'admin_id')
on conflict (workspace_id, profile_id) do nothing;

-- ============================================================
-- Source: WEECO Pharma GmbH (company_primary, DE)
-- ============================================================
insert into sources (
  id, name, canonical_url, domain, source_tier, status,
  jurisdiction, entity_type, contact_org, description, created_by_profile_id
) values (
  :'source_id',
  'WEECO Pharma GmbH',
  'https://www.weeco-pharma.de',
  'weeco-pharma.de',
  'company_primary',
  'active',
  'DE',
  'company',
  'WEECO Pharma GmbH',
  'Licensed cannabis importer and distributor in Germany. Key gatekeeper in the German medical cannabis wholesale channel.',
  :'admin_id'
)
on conflict (id) do nothing;

-- ============================================================
-- Source document: BfArM import notice (URL-only — ADR-001 D2)
-- ============================================================
insert into source_documents (
  id, source_id, title, url, publication_date, status, parsed_content, created_by_profile_id
) values (
  :'doc_id',
  :'source_id',
  'BfArM Cannabis Import Authorization — WEECO Pharma GmbH Q1 2025',
  'https://www.bfarm.de/SharedDocs/Bekanntmachungen/DE/Betaeubungsmittel/cannabis-weeco-2025-q1.html',
  '2025-02-01',
  'parsed',
  'The BfArM has issued an import authorization to WEECO Pharma GmbH for cannabis flower (THC >0.2%) under §3 BtMG for the period January–March 2025. Volume authorized: 500 kg. Origin: Portugal (Tilray). Wholesale distribution permitted to licensed pharmacies only.',
  :'analyst_id'
)
on conflict (id) do nothing;

-- ============================================================
-- Signal: WEECO Q1 2025 import authorization
-- ============================================================
insert into signals (
  id, title, summary, signal_type, jurisdiction, event_date,
  entity_name, entity_org, data_class, confidence_level,
  review_status, visibility_scope, source_id, created_by_profile_id
) values (
  :'signal_id',
  'WEECO Pharma GmbH — BfArM Q1 2025 import authorization confirmed',
  'WEECO Pharma GmbH received a BfArM import authorization for 500 kg cannabis flower (THC >0.2%) from Tilray Portugal for Q1 2025. Distribution limited to licensed German pharmacies under §3 BtMG.',
  'licensing_update',
  'DE',
  '2025-02-01',
  'WEECO Pharma GmbH',
  'WEECO Pharma GmbH',
  'observed',
  'high',
  'draft',
  'internal',
  :'source_id',
  :'analyst_id'
)
on conflict (id) do nothing;

-- ============================================================
-- Evidence record (human-verified — required for approval per non-negotiable rule 2)
-- ============================================================
insert into signal_evidence (
  id, signal_id, source_document_id, evidence_type, evidence_source_type,
  evidence_text, citation_reference, created_by_profile_id
) values (
  :'evidence_id',
  :'signal_id',
  :'doc_id',
  'paraphrased_fact',
  'human',
  'BfArM issued WEECO Pharma GmbH an import authorization for 500 kg cannabis flower (THC >0.2%) from Tilray Portugal for Q1 2025, restricted to wholesale distribution to licensed pharmacies under §3 BtMG.',
  'BfArM Bekanntmachungen — WEECO Q1 2025, paragraph 1',
  :'analyst_id'
)
on conflict (id) do nothing;

-- ============================================================
-- Submit signal for review
-- CORRECTION [2]: review_queue_items inserted with status = 'pending'
-- (was 'under_review' in prior version — inconsistent with the corrected
-- server action submitSignalForReview which inserts 'pending')
-- ============================================================
update signals set
  review_status           = 'in_review',
  submitted_at            = now(),
  submitted_by_profile_id = :'analyst_id'
where id = :'signal_id';

insert into review_queue_items (id, signal_id, status, submitted_by_profile_id, assigned_to_profile_id)
values (:'rq_id', :'signal_id', 'pending', :'analyst_id', :'admin_id')
on conflict (id) do nothing;

-- ============================================================
-- Approve signal (admin action)
-- ============================================================
update signals set
  review_status           = 'approved',
  reviewed_at             = now(),
  reviewed_by_profile_id  = :'admin_id'
where id = :'signal_id';

update review_queue_items set
  status                  = 'approved',
  resolved_at             = now(),
  resolved_by_profile_id  = :'admin_id'
where id = :'rq_id';

-- ============================================================
-- Dossier: created as draft, moved to ready_for_publish
-- (two pre-publish updates — safe, trigger only fires when OLD.status = 'published')
-- ============================================================
insert into dossiers (id, workspace_id, title, summary, status, jurisdiction, created_by_profile_id) values
  (:'dossier_id',
   :'workspace_id',
   'Germany Cannabis Market Intelligence — Q1 2025',
   'Regulatory and licensing signals for the German medical cannabis wholesale channel, Q1 2025. Anchored to WEECO Pharma GmbH BfArM authorization.',
   'draft',
   'DE',
   :'admin_id')
on conflict (id) do nothing;

-- Dossier item
insert into dossier_items (id, dossier_id, signal_id, display_order, created_by_profile_id) values
  (:'di_id', :'dossier_id', :'signal_id', 1, :'admin_id')
on conflict (id) do nothing;

update dossiers set status = 'ready_for_publish'
where id = :'dossier_id';

-- ============================================================
-- Publish event with CORRECTED snapshot_json
-- CORRECTION [1]: snapshot now includes full evidence chain with
-- source_document provenance, schema_version, effective_at, and
-- workspace block — matching publishDossier() corrected output.
-- CORRECTION [4]: api_token is clearly a dev-only seed token.
-- ============================================================
insert into publish_events (
  id, dossier_id, workspace_id, status, published_by_profile_id,
  snapshot_json, api_token
) values (
  :'pe_id',
  :'dossier_id',
  :'workspace_id',
  'completed',
  :'admin_id',
  '{
    "schema_version": "1.0",
    "dossier_id": "00000000-0000-0000-0000-000000000070",
    "title": "Germany Cannabis Market Intelligence — Q1 2025",
    "summary": "Regulatory and licensing signals for the German medical cannabis wholesale channel, Q1 2025. Anchored to WEECO Pharma GmbH BfArM authorization.",
    "jurisdiction": "DE",
    "version_number": 1,
    "supersedes_dossier_id": null,
    "published_at": null,
    "effective_at": null,
    "workspace": {
      "id": "00000000-0000-0000-0000-000000000010",
      "name": "Germany Intelligence"
    },
    "signals": [
      {
        "id": "00000000-0000-0000-0000-000000000040",
        "title": "WEECO Pharma GmbH — BfArM Q1 2025 import authorization confirmed",
        "summary": "WEECO Pharma GmbH received a BfArM import authorization for 500 kg cannabis flower (THC >0.2%) from Tilray Portugal for Q1 2025. Distribution limited to licensed German pharmacies under §3 BtMG.",
        "signal_type": "licensing_update",
        "jurisdiction": "DE",
        "event_date": "2025-02-01",
        "entity_name": "WEECO Pharma GmbH",
        "entity_org": "WEECO Pharma GmbH",
        "data_class": "observed",
        "confidence_level": "high",
        "display_order": 1,
        "evidence": [
          {
            "id": "00000000-0000-0000-0000-000000000050",
            "evidence_type": "paraphrased_fact",
            "evidence_source_type": "human",
            "evidence_text": "BfArM issued WEECO Pharma GmbH an import authorization for 500 kg cannabis flower (THC >0.2%) from Tilray Portugal for Q1 2025, restricted to wholesale distribution to licensed pharmacies under §3 BtMG.",
            "citation_reference": "BfArM Bekanntmachungen — WEECO Q1 2025, paragraph 1",
            "source_document": {
              "id": "00000000-0000-0000-0000-000000000030",
              "title": "BfArM Cannabis Import Authorization — WEECO Pharma GmbH Q1 2025",
              "url": "https://www.bfarm.de/SharedDocs/Bekanntmachungen/DE/Betaeubungsmittel/cannabis-weeco-2025-q1.html",
              "publication_date": "2025-02-01"
            }
          }
        ]
      }
    ]
  }',
  'hvfeed_seed_dev_only_00000000000000000000000000000090'
)
on conflict (id) do nothing;

-- ============================================================
-- Mark dossier published — SINGLE atomic update
-- CORRECTION [3]: status + published_at + published_by_profile_id in
-- one statement. The block_published_dossier_mutation() trigger fires
-- on ANY update once status = 'published', so splitting this into two
-- statements would block the second. One shot only.
-- ============================================================
update dossiers set
  status                  = 'published',
  published_at            = now(),
  published_by_profile_id = :'admin_id'
where id = :'dossier_id';

-- ============================================================
-- Audit trail for the golden path
-- ============================================================
select write_audit_event('signal',  :'signal_id',  'create',           :'analyst_id', null,             'draft',     'Signal created',                                        null, :'workspace_id');
select write_audit_event('signal',  :'signal_id',  'submit_for_review', :'analyst_id', 'draft',         'in_review', 'Signal submitted for review',                           null, :'workspace_id');
select write_audit_event('signal',  :'signal_id',  'approve',          :'admin_id',   'in_review',      'approved',  'Signal approved by admin',                              null, :'workspace_id');
select write_audit_event('dossier', :'dossier_id', 'create',           :'admin_id',   null,             'draft',     'Dossier created',                                       null, :'workspace_id');
select write_audit_event('dossier', :'dossier_id', 'publish',          :'admin_id',   'ready_for_publish', 'published', 'Dossier published to Germany Intelligence workspace', null, :'workspace_id');

-- ============================================================
-- Negative-path seed: rejected signal (no evidence, unverified)
-- Used by N1 conceptually — the actual N1 test creates its own signal
-- at runtime, so this is for manual inspection / dev exploration only.
-- ============================================================
insert into signals (
  title, summary, signal_type, jurisdiction, data_class, confidence_level,
  review_status, visibility_scope, source_id, created_by_profile_id
) values (
  'Unverified WEECO distribution rumour — rejected',
  'Forum claim that WEECO is expanding to Austria. No primary source found.',
  'market_entry',
  'AT',
  'unverified',
  'low',
  'rejected',
  'internal',
  :'source_id',
  :'analyst_id'
)
on conflict do nothing;

select write_audit_event(
  'signal',
  (select id from signals where title = 'Unverified WEECO distribution rumour — rejected' limit 1),
  'reject', :'admin_id', 'in_review', 'rejected',
  'Rejected: no primary source, community-only origin',
  null, :'workspace_id'
);

-- ============================================================
-- Verification query — run after applying seed to confirm state
-- Uncomment to check:
--
-- select
--   s.title,
--   s.review_status,
--   count(se.id) as evidence_count,
--   d.status as dossier_status,
--   pe.api_token
-- from signals s
-- left join signal_evidence se on se.signal_id = s.id
-- left join dossier_items di on di.signal_id = s.id
-- left join dossiers d on d.id = di.dossier_id
-- left join publish_events pe on pe.dossier_id = d.id and pe.status = 'completed'
-- where s.id = '00000000-0000-0000-0000-000000000040'
-- group by s.title, s.review_status, d.status, pe.api_token;
--
-- Expected:
--   review_status = 'approved'
--   evidence_count = 1
--   dossier_status = 'published'
--   api_token = 'hvfeed_seed_dev_only_00000000000000000000000000000090'
-- ============================================================
