-- 0012_germany_operator_seed.sql
-- Harbourview Production Spine — Germany 5-operator real dataset (OI-3 closed)
--
-- SOURCE: Harbourview_operational_spine_workbook_germany_pressure_test.xlsx
-- All column names verified against 0001–0007 DDL on April 20 2026.
--
-- WHAT THIS ADDS (fully additive — zero overlap with 0009 golden-path fixtures):
--   • Workspace "Germany Operator Intelligence" (client, is_internal=false)
--   • 5 real operators: Adjupharm, Bathera, FOUR 20 PHARMA, Nimbus Health, WEECO
--   • 5 sources + 5 source_documents + 5 signals + 5 evidence rows
--   • 1 published dossier with 5 dossier_items + 1 publish_event
--   • Audit trail (create+approve ×5 signals, create+publish for dossier)
--
-- CORRECTIONS vs first draft (column name fixes):
--   source_documents : raw_text        → parsed_content (DDL col name)
--                      captured_at     → removed (no such column)
--                      citation_ref    → internal_notes (DDL col name)
--   dossier_items    : client_commentary → item_notes (DDL col name)
--   publish_events   : published_by_profile_id added (NOT NULL constraint)
--
-- UUID block 000...0100+ — no overlap with 0009 (000...00xx):
--   Workspace  00000000-0000-0000-0000-000000000100
--   Sources    00000000-0000-0000-0000-00000000011{0..4}
--   Docs       00000000-0000-0000-0000-00000000012{0..4}
--   Signals    00000000-0000-0000-0000-00000000013{0..4}
--   Evidence   00000000-0000-0000-0000-00000000014{0..4}
--   Dossier    00000000-0000-0000-0000-000000000200
--   D-Items    00000000-0000-0000-0000-00000000016{0..4}
--   Pub-event  00000000-0000-0000-0000-000000000300
--
-- PREREQUISITE: 0009 applied (admin_id + analyst_id profiles exist in DB).
-- Running standalone? Uncomment the two \set lines:
-- \set admin_id   '9866753f-1a8d-495c-8ab8-d0d1eebfce04'
-- \set analyst_id '31e6281c-aec9-4c6d-a9c3-4852b1c057d5'

-- ============================================================
-- Workspace
-- ============================================================
insert into workspaces (id, name, slug, is_internal, created_by_profile_id)
values (
  '00000000-0000-0000-0000-000000000100',
  'Germany Operator Intelligence',
  'germany-operator-intelligence',
  false,
  :'admin_id'
) on conflict (id) do nothing;

insert into workspace_members (workspace_id, profile_id, workspace_role, added_by_profile_id)
values
  ('00000000-0000-0000-0000-000000000100', :'admin_id',   'owner',  :'admin_id'),
  ('00000000-0000-0000-0000-000000000100', :'analyst_id', 'editor', :'admin_id')
on conflict (workspace_id, profile_id) do nothing;

-- ============================================================
-- Sources
-- ============================================================
insert into sources (
  id, name, canonical_url, domain,
  source_tier, entity_type, status, jurisdiction,
  contact_org,
  created_by_profile_id, updated_by_profile_id
) values
  ('00000000-0000-0000-0000-000000000110','Adjupharm GmbH official site',
   'https://www.adjupharm.de/','adjupharm.de','company_primary','company','active','DE',
   'Adjupharm GmbH',:'admin_id',:'admin_id'),
  ('00000000-0000-0000-0000-000000000111','Bathera GmbH official site',
   'https://bathera.com/','bathera.com','company_primary','company','active','DE',
   'Bathera GmbH',:'admin_id',:'admin_id'),
  ('00000000-0000-0000-0000-000000000112','FOUR 20 PHARMA GmbH official site',
   'https://420pharma.de/en/','420pharma.de','company_primary','company','active','DE',
   'FOUR 20 PHARMA GmbH',:'admin_id',:'admin_id'),
  ('00000000-0000-0000-0000-000000000113','Dr. Reddy''s / Nimbus Health corporate disclosure',
   'https://www.drreddys.com/generics','drreddys.com','company_primary','company','active','DE',
   'Nimbus Health GmbH',:'admin_id',:'admin_id'),
  ('00000000-0000-0000-0000-000000000114','WEECO Pharma GmbH official site',
   'https://weeco.com/en/','weeco.com','company_primary','company','active','DE',
   'WEECO Pharma GmbH',:'admin_id',:'admin_id')
on conflict (id) do nothing;

-- ============================================================
-- Source documents
-- Confirmed columns: id, source_id, title, url, status,
--   parsed_content (extracted text), internal_notes,
--   created_by_profile_id, updated_by_profile_id
-- No captured_at column — created_at defaults to now()
-- ============================================================
insert into source_documents (
  id, source_id, title, url, status,
  parsed_content, internal_notes,
  created_by_profile_id, updated_by_profile_id
) values
  ('00000000-0000-0000-0000-000000000120','00000000-0000-0000-0000-000000000110',
   'Adjupharm company profile','https://www.adjupharm.de/','captured',
   'Adjupharm distributes 12 brands from 9 countries and focuses on supplying pharmacies in Germany.',
   'Company profile / products sections',:'admin_id',:'admin_id'),
  ('00000000-0000-0000-0000-000000000121','00000000-0000-0000-0000-000000000111',
   'Bathera company overview','https://bathera.com/','captured',
   'Bathera describes itself as headquartered in Germany with cultivation in Portugal and active distribution in Germany and Australia.',
   'Homepage overview / company notice',:'admin_id',:'admin_id'),
  ('00000000-0000-0000-0000-000000000122','00000000-0000-0000-0000-000000000112',
   'FOUR 20 PHARMA company overview','https://420pharma.de/en/','captured',
   'FOUR 20 PHARMA says it has been a global player since 2018 and has been part of Curaleaf International since the end of 2022.',
   'About us section',:'admin_id',:'admin_id'),
  ('00000000-0000-0000-0000-000000000123','00000000-0000-0000-0000-000000000113',
   'Dr. Reddy''s Nimbus platform disclosure','https://www.drreddys.com/generics','captured',
   'Nimbus Health is a licensed pharmaceutical wholesaler focused on medical cannabis and operates in Germany under Dr. Reddy''s.',
   'Nimbus Health section',:'admin_id',:'admin_id'),
  ('00000000-0000-0000-0000-000000000124','00000000-0000-0000-0000-000000000114',
   'WEECO company overview','https://weeco.com/en/','captured',
   'WEECO describes operations along the cannabis supply chain and a footprint spanning Germany and several other European markets.',
   'Homepage / company overview',:'admin_id',:'admin_id')
on conflict (id) do nothing;

-- ============================================================
-- Signals — all approved, one per operator
-- ============================================================
insert into signals (
  id, title, summary, signal_type, jurisdiction,
  event_date, entity_name, entity_org,
  data_class, confidence_level, review_status, visibility_scope,
  source_id, created_by_profile_id, updated_by_profile_id
) values
  (
    '00000000-0000-0000-0000-000000000130',
    'Adjupharm profile shows broad pharmacy-facing brand access in Germany',
    'Adjupharm says it distributes 12 cannabis brands from 9 countries to pharmacies in Germany as part of IM Cannabis''s German platform.',
    'distribution','DE','2026-04-15','Adjupharm GmbH','Adjupharm GmbH',
    'observed','high','approved','internal',
    '00000000-0000-0000-0000-000000000110',:'admin_id',:'admin_id'
  ),
  (
    '00000000-0000-0000-0000-000000000131',
    'Bathera is operating across Germany, Portugal and Australia with additional expansion targets',
    'Bathera positions itself as a vertically integrated medical cannabis operator headquartered in Germany with cultivation in Portugal and active distribution in Germany and Australia.',
    'market_entry','DE','2026-04-15','Bathera GmbH','Bathera GmbH',
    'observed','high','approved','internal',
    '00000000-0000-0000-0000-000000000111',:'admin_id',:'admin_id'
  ),
  (
    '00000000-0000-0000-0000-000000000132',
    'FOUR 20 PHARMA remains a German market-access platform under Curaleaf International',
    'FOUR 20 PHARMA says it has been active since 2018 and has been part of Curaleaf International since the end of 2022.',
    'ownership','DE','2026-04-15','FOUR 20 PHARMA GmbH','FOUR 20 PHARMA GmbH',
    'observed','high','approved','internal',
    '00000000-0000-0000-0000-000000000112',:'admin_id',:'admin_id'
  ),
  (
    '00000000-0000-0000-0000-000000000133',
    'Nimbus operates as Dr. Reddy''s German medical cannabis platform',
    'Dr. Reddy''s says Nimbus Health is a licensed pharmaceutical wholesaler focused on medical cannabis and continues to operate under the Nimbus brand.',
    'ownership','DE','2022-02-03','Nimbus Health GmbH','Nimbus Health GmbH',
    'observed','high','approved','internal',
    '00000000-0000-0000-0000-000000000113',:'admin_id',:'admin_id'
  ),
  (
    '00000000-0000-0000-0000-000000000134',
    'WEECO presents itself as a multi-market cannabis supply-chain operator',
    'WEECO says it operates cannabis ventures across Germany and several other European markets with activity along the supply chain.',
    'company_profile','DE','2026-04-15','WEECO Pharma GmbH','WEECO Pharma GmbH',
    'observed','medium','approved','internal',
    '00000000-0000-0000-0000-000000000114',:'admin_id',:'admin_id'
  )
on conflict (id) do nothing;

-- ============================================================
-- Signal evidence — paraphrased_fact, human, one per signal
-- ============================================================
insert into signal_evidence (
  id, signal_id, source_document_id,
  evidence_type, evidence_source_type,
  evidence_text, citation_reference,
  created_by_profile_id
) values
  ('00000000-0000-0000-0000-000000000140','00000000-0000-0000-0000-000000000130','00000000-0000-0000-0000-000000000120',
   'paraphrased_fact','human',
   'Adjupharm states that it distributes 12 brands from 9 countries to pharmacies in Germany.',
   'Company profile / products sections',:'admin_id'),
  ('00000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000131','00000000-0000-0000-0000-000000000121',
   'paraphrased_fact','human',
   'Bathera says it is headquartered in Germany, cultivates in Portugal and is distributing in Germany and Australia.',
   'Homepage overview / company notice',:'admin_id'),
  ('00000000-0000-0000-0000-000000000142','00000000-0000-0000-0000-000000000132','00000000-0000-0000-0000-000000000122',
   'paraphrased_fact','human',
   'FOUR 20 PHARMA states that it has been active since 2018 and part of Curaleaf International since late 2022.',
   'About us section',:'admin_id'),
  ('00000000-0000-0000-0000-000000000143','00000000-0000-0000-0000-000000000133','00000000-0000-0000-0000-000000000123',
   'paraphrased_fact','human',
   'Dr. Reddy''s describes Nimbus as a licensed pharmaceutical wholesaler focused on medical cannabis in Germany.',
   'Nimbus Health section',:'admin_id'),
  ('00000000-0000-0000-0000-000000000144','00000000-0000-0000-0000-000000000134','00000000-0000-0000-0000-000000000124',
   'paraphrased_fact','human',
   'WEECO says it runs cannabis ventures across multiple European markets and along the supply chain.',
   'Homepage / company overview',:'admin_id')
on conflict (id) do nothing;

-- ============================================================
-- Dossier
-- ============================================================
insert into dossiers (
  id, workspace_id, title, summary, status, jurisdiction,
  created_by_profile_id
) values (
  '00000000-0000-0000-0000-000000000200',
  '00000000-0000-0000-0000-000000000100',
  'Germany Operator Intelligence Brief — April 2026',
  'Initial Germany pressure-test pack using five mapped operators and public-source evidence only. Adjupharm, Bathera, FOUR 20 PHARMA, Nimbus Health, WEECO.',
  'draft','DE',:'admin_id'
) on conflict (id) do nothing;

-- ============================================================
-- Dossier items
-- item_notes = internal editorial note (workbook called this client_visible_commentary)
-- ============================================================
insert into dossier_items (
  id, dossier_id, signal_id, display_order, item_notes, created_by_profile_id
) values
  ('00000000-0000-0000-0000-000000000160','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000130',1,
   'Adjupharm looks like a practical distribution-platform profile rather than a generic brand shell.',:'admin_id'),
  ('00000000-0000-0000-0000-000000000161','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000131',2,
   'Bathera is relevant because it combines upstream production with downstream European distribution.',:'admin_id'),
  ('00000000-0000-0000-0000-000000000162','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000132',3,
   'FOUR 20 PHARMA should be treated as a local access point inside a larger global group.',:'admin_id'),
  ('00000000-0000-0000-0000-000000000163','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000133',4,
   'Nimbus remains relevant because pharma ownership can change decision speed and risk tolerance.',:'admin_id'),
  ('00000000-0000-0000-0000-000000000164','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000134',5,
   'WEECO is mapped as a supply-chain operator that still needs license-level validation.',:'admin_id')
on conflict (id) do nothing;

-- ============================================================
-- Publish event
-- published_by_profile_id is NOT NULL — must be supplied
-- api_token length ≤ 50 chars to be safe against unique text index
-- ============================================================
insert into publish_events (
  id, dossier_id, workspace_id, status,
  published_by_profile_id, api_token, snapshot_json
) values (
  '00000000-0000-0000-0000-000000000300',
  '00000000-0000-0000-0000-000000000200',
  '00000000-0000-0000-0000-000000000100',
  'completed',
  :'admin_id',
  'hvfeed_seed_dev_only_germany_ops_0000000300',
  jsonb_build_object(
    'schema_version','1.0',
    'dossier_id','00000000-0000-0000-0000-000000000200',
    'title','Germany Operator Intelligence Brief — April 2026',
    'jurisdiction','DE',
    'version_number',1,
    'workspace',jsonb_build_object(
      'id','00000000-0000-0000-0000-000000000100',
      'name','Germany Operator Intelligence'
    ),
    'signals',jsonb_build_array(
      jsonb_build_object(
        'id','00000000-0000-0000-0000-000000000130',
        'title','Adjupharm profile shows broad pharmacy-facing brand access in Germany',
        'summary','Adjupharm says it distributes 12 cannabis brands from 9 countries to pharmacies in Germany.',
        'signal_type','distribution','data_class','observed','confidence_level','high','display_order',1,
        'evidence',jsonb_build_array(jsonb_build_object(
          'id','00000000-0000-0000-0000-000000000140',
          'evidence_type','paraphrased_fact','evidence_source_type','human',
          'evidence_text','Adjupharm states that it distributes 12 brands from 9 countries to pharmacies in Germany.',
          'citation_reference','Company profile / products sections',
          'source_document',jsonb_build_object(
            'id','00000000-0000-0000-0000-000000000120',
            'title','Adjupharm company profile',
            'url','https://www.adjupharm.de/','publication_date',null)))),
      jsonb_build_object(
        'id','00000000-0000-0000-0000-000000000131',
        'title','Bathera is operating across Germany, Portugal and Australia with additional expansion targets',
        'summary','Bathera positions itself as a vertically integrated operator headquartered in Germany.',
        'signal_type','market_entry','data_class','observed','confidence_level','high','display_order',2,
        'evidence',jsonb_build_array(jsonb_build_object(
          'id','00000000-0000-0000-0000-000000000141',
          'evidence_type','paraphrased_fact','evidence_source_type','human',
          'evidence_text','Bathera says it is headquartered in Germany, cultivates in Portugal and is distributing in Germany and Australia.',
          'citation_reference','Homepage overview / company notice',
          'source_document',jsonb_build_object(
            'id','00000000-0000-0000-0000-000000000121',
            'title','Bathera company overview',
            'url','https://bathera.com/','publication_date',null)))),
      jsonb_build_object(
        'id','00000000-0000-0000-0000-000000000132',
        'title','FOUR 20 PHARMA remains a German market-access platform under Curaleaf International',
        'summary','FOUR 20 PHARMA says it has been active since 2018 and part of Curaleaf International since late 2022.',
        'signal_type','ownership','data_class','observed','confidence_level','high','display_order',3,
        'evidence',jsonb_build_array(jsonb_build_object(
          'id','00000000-0000-0000-0000-000000000142',
          'evidence_type','paraphrased_fact','evidence_source_type','human',
          'evidence_text','FOUR 20 PHARMA states that it has been active since 2018 and part of Curaleaf International since late 2022.',
          'citation_reference','About us section',
          'source_document',jsonb_build_object(
            'id','00000000-0000-0000-0000-000000000122',
            'title','FOUR 20 PHARMA company overview',
            'url','https://420pharma.de/en/','publication_date',null)))),
      jsonb_build_object(
        'id','00000000-0000-0000-0000-000000000133',
        'title','Nimbus operates as Dr. Reddy''s German medical cannabis platform',
        'summary','Dr. Reddy''s says Nimbus Health is a licensed pharmaceutical wholesaler focused on medical cannabis in Germany.',
        'signal_type','ownership','data_class','observed','confidence_level','high','display_order',4,
        'evidence',jsonb_build_array(jsonb_build_object(
          'id','00000000-0000-0000-0000-000000000143',
          'evidence_type','paraphrased_fact','evidence_source_type','human',
          'evidence_text','Dr. Reddy''s describes Nimbus as a licensed pharmaceutical wholesaler focused on medical cannabis in Germany.',
          'citation_reference','Nimbus Health section',
          'source_document',jsonb_build_object(
            'id','00000000-0000-0000-0000-000000000123',
            'title','Dr. Reddy''s Nimbus platform disclosure',
            'url','https://www.drreddys.com/generics','publication_date','2022-02-03')))),
      jsonb_build_object(
        'id','00000000-0000-0000-0000-000000000134',
        'title','WEECO presents itself as a multi-market cannabis supply-chain operator',
        'summary','WEECO says it operates cannabis ventures across Germany and several other European markets.',
        'signal_type','company_profile','data_class','observed','confidence_level','medium','display_order',5,
        'evidence',jsonb_build_array(jsonb_build_object(
          'id','00000000-0000-0000-0000-000000000144',
          'evidence_type','paraphrased_fact','evidence_source_type','human',
          'evidence_text','WEECO says it runs cannabis ventures across multiple European markets and along the supply chain.',
          'citation_reference','Homepage / company overview',
          'source_document',jsonb_build_object(
            'id','00000000-0000-0000-0000-000000000124',
            'title','WEECO company overview',
            'url','https://weeco.com/en/','publication_date',null))))
    )
  )
) on conflict (id) do nothing;

-- ============================================================
-- Mark dossier published — single atomic update
-- ============================================================
update dossiers set
  status                  = 'published',
  published_at            = now(),
  published_by_profile_id = :'admin_id'
where id = '00000000-0000-0000-0000-000000000200';

-- ============================================================
-- Audit trail
-- ============================================================
select write_audit_event('signal','00000000-0000-0000-0000-000000000130','create',  :'admin_id',null,    'draft',   'Adjupharm signal created',          null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000130','approve', :'admin_id','draft', 'approved','Adjupharm signal approved',         null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000131','create',  :'admin_id',null,    'draft',   'Bathera signal created',            null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000131','approve', :'admin_id','draft', 'approved','Bathera signal approved',           null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000132','create',  :'admin_id',null,    'draft',   'FOUR 20 PHARMA signal created',     null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000132','approve', :'admin_id','draft', 'approved','FOUR 20 PHARMA signal approved',    null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000133','create',  :'admin_id',null,    'draft',   'Nimbus Health signal created',      null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000133','approve', :'admin_id','draft', 'approved','Nimbus Health signal approved',     null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000134','create',  :'admin_id',null,    'draft',   'WEECO signal created',              null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000134','approve', :'admin_id','draft', 'approved','WEECO signal approved',             null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('dossier','00000000-0000-0000-0000-000000000200','create',  :'admin_id',null,               'draft',    'Germany operator dossier created', null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('dossier','00000000-0000-0000-0000-000000000200','publish', :'admin_id','ready_for_publish','published','Germany operator dossier published',null,'00000000-0000-0000-0000-000000000100');

-- ============================================================
-- Verification — paste into SQL editor after applying:
--
-- select s.title, s.review_status, count(se.id) as evidence_count, d.status as dossier_status
-- from signals s
-- join signal_evidence se on se.signal_id = s.id
-- join dossier_items di on di.signal_id = s.id
-- join dossiers d on d.id = di.dossier_id
-- where d.id = '00000000-0000-0000-0000-000000000200'
-- group by s.title, s.review_status, d.status
-- order by s.title;
-- Expected: 5 rows, review_status='approved', evidence_count=1, dossier_status='published'
-- ============================================================
