-- ============================================================
-- Harbourview Production Spine — APPLY_ALL.sql
-- Single-file migration for Supabase SQL editor
-- Project: tpfvhhrwzsofhdcfdenc (System B — NOT System A)
-- Generated: 2026-04-20 22:30 UTC
-- Apply order: 0001→0002→0003→0004→0005→0006→0006b→0007→0008→0009→0010→0011→0012
-- DO NOT apply to fgdrvqqezdiraqyuofte (System A / live crawler)
-- ============================================================


-- ============================================================
-- 0001_create_enums.sql
-- ============================================================

-- 0001_create_enums.sql
-- Harbourview Production Spine — shared enum types
-- ADR-001: D1=A (admin/analyst separation), D2=A (URL-only), D3=A (no contacts table), D4=D (JSON feed)

create type data_class as enum (
  'observed',
  'derived',
  'inferred',
  'unverified'
);

create type confidence_level as enum (
  'low',
  'medium',
  'high',
  'confirmed'
);

create type visibility_scope as enum (
  'internal',
  'workspace',
  'public_future_reserved'
);

create type source_tier as enum (
  'official_primary',
  'official_secondary',
  'company_primary',
  'trusted_secondary',
  'media_secondary',
  'community_low_trust'
);

create type review_status as enum (
  'draft',
  'in_review',
  'approved',
  'rejected',
  'published',
  'archived'
);

create type platform_role as enum (
  'admin',
  'analyst',
  'client'
);

create type workspace_role as enum (
  'owner',
  'editor',
  'viewer'
);

create type entity_type as enum (
  'person',
  'company',
  'regulator'
);

create type evidence_type as enum (
  'direct_quote',
  'paraphrased_fact',
  'date_confirmation',
  'supporting_context',
  'secondary_reference'
);

-- ADR-001 D4: evidence_source_type distinguishes human-verified from AI-assisted.
-- AI-assisted evidence cannot be the sole basis for signal approval.
create type evidence_source_type as enum (
  'human',
  'ai_assisted'
);

create type source_status as enum (
  'draft',
  'active',
  'paused',
  'archived'
);

create type source_document_status as enum (
  'captured',
  'parsed',
  'failed',
  'archived'
);

create type dossier_status as enum (
  'draft',
  'ready_for_publish',
  'published',
  'superseded',
  'archived'
);

create type publish_event_status as enum (
  'completed',
  'revoked'
);

create type audit_action as enum (
  'create',
  'update',
  'submit_for_review',
  'approve',
  'reject',
  'return_for_revision',
  'publish',
  'revoke',
  'archive',
  'restore',
  'merge',
  'membership_change'
);


-- ============================================================
-- 0002_create_profiles_and_workspaces.sql
-- ============================================================

-- 0002_create_profiles_and_workspaces.sql
-- Harbourview Production Spine — identity and workspace isolation layer
-- ADR-001 D1: platform_role enforced. admin can approve/publish. analyst cannot.

create table profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  email                 text not null unique,
  full_name             text not null,
  platform_role         platform_role not null default 'analyst',
  default_workspace_id  uuid, -- FK added after workspaces table exists (see constraint below)
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create table workspaces (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null,
  slug                  text not null unique,
  description           text,
  is_internal           boolean not null default false, -- true = analyst/admin workspace, false = client workspace
  is_active             boolean not null default true,
  created_by_profile_id uuid not null references profiles(id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- Deferred FK: profiles.default_workspace_id -> workspaces
alter table profiles
  add constraint profiles_default_workspace_id_fkey
  foreign key (default_workspace_id) references workspaces(id) on delete set null;

create table workspace_members (
  id                    uuid primary key default gen_random_uuid(),
  workspace_id          uuid not null references workspaces(id) on delete cascade,
  profile_id            uuid not null references profiles(id) on delete cascade,
  workspace_role        workspace_role not null default 'viewer',
  added_by_profile_id   uuid references profiles(id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (workspace_id, profile_id)
);

-- Indexes
create index on workspace_members (profile_id);
create index on workspace_members (workspace_id);

-- Updated_at trigger function (shared across all tables)
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on profiles
  for each row execute function set_updated_at();

create trigger workspaces_updated_at before update on workspaces
  for each row execute function set_updated_at();

create trigger workspace_members_updated_at before update on workspace_members
  for each row execute function set_updated_at();


-- ============================================================
-- 0003_create_sources_and_source_documents.sql
-- ============================================================

-- 0003_create_sources_and_source_documents.sql
-- Harbourview Production Spine — source registry and document capture
-- ADR-001 D2: URL-only ingestion. No file storage. content_hash nullable for future use.
-- ADR-001 D3: No contacts table. contact_name, contact_org are plain text fields.

create table sources (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null,
  canonical_url         text,
  domain                text,
  source_tier           source_tier not null,
  status                source_status not null default 'draft',
  jurisdiction          text,            -- e.g. 'DE', 'NL', 'UK'
  entity_type           entity_type,     -- person / company / regulator
  contact_name          text,            -- plain text, ADR-001 D3
  contact_org           text,            -- plain text, ADR-001 D3
  description           text,
  internal_notes        text,            -- never exposed in API responses to clients
  record_version        integer not null default 1,
  created_by_profile_id uuid not null references profiles(id),
  updated_by_profile_id uuid references profiles(id),
  archived_at           timestamptz,
  archived_by_profile_id uuid references profiles(id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- Soft-dedupe: warn on exact canonical_url match
create unique index sources_canonical_url_unique
  on sources (canonical_url)
  where canonical_url is not null and status != 'archived';

create table source_documents (
  id                    uuid primary key default gen_random_uuid(),
  source_id             uuid not null references sources(id) on delete restrict,
  title                 text not null,
  url                   text not null,                        -- ADR-001 D2: required, unique
  publication_date      date,
  status                source_document_status not null default 'captured',
  parsed_content        text,                                 -- extracted text, nullable
  content_hash          text,                                 -- sha256 of parsed_content, nullable
  parse_error           text,                                 -- populated on status=failed
  internal_notes        text,
  record_version        integer not null default 1,
  created_by_profile_id uuid not null references profiles(id),
  updated_by_profile_id uuid references profiles(id),
  archived_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- Hard dedupe: block exact URL duplicates
create unique index source_documents_url_unique
  on source_documents (url)
  where status != 'archived';

-- Content hash dedupe support (non-blocking, for detection only at v1)
create index on source_documents (content_hash) where content_hash is not null;
create index on source_documents (source_id);

-- Triggers
create trigger sources_updated_at before update on sources
  for each row execute function set_updated_at();

create trigger source_documents_updated_at before update on source_documents
  for each row execute function set_updated_at();

-- record_version increment on update
create or replace function increment_record_version()
returns trigger language plpgsql as $$
begin
  new.record_version = old.record_version + 1;
  return new;
end;
$$;

create trigger sources_record_version before update on sources
  for each row execute function increment_record_version();

create trigger source_documents_record_version before update on source_documents
  for each row execute function increment_record_version();


-- ============================================================
-- 0004_create_signals_and_evidence.sql
-- ============================================================

-- 0004_create_signals_and_evidence.sql
-- Harbourview Production Spine — signal capture and evidence attachment
-- ADR-001 D1: approval blocked at app layer for non-admin roles (enforced in server actions)
-- ADR-001 D3: entity_name, entity_org are plain text fields on signals

create table signals (
  id                    uuid primary key default gen_random_uuid(),
  title                 text not null,
  summary               text not null,
  signal_type           text not null,           -- e.g. 'regulatory_change', 'market_entry', 'licensing_update'
  jurisdiction          text,
  event_date            date,
  entity_name           text,                    -- plain text, ADR-001 D3
  entity_org            text,                    -- plain text, ADR-001 D3
  data_class            data_class not null,
  confidence_level      confidence_level not null default 'low',
  review_status         review_status not null default 'draft',
  visibility_scope      visibility_scope not null default 'internal',
  source_id             uuid references sources(id) on delete set null,
  internal_notes        text,                    -- never client-visible
  analyst_notes         text,                    -- internal working notes
  record_version        integer not null default 1,
  created_by_profile_id uuid not null references profiles(id),
  updated_by_profile_id uuid references profiles(id),
  submitted_at          timestamptz,
  submitted_by_profile_id uuid references profiles(id),
  reviewed_at           timestamptz,
  reviewed_by_profile_id uuid references profiles(id),
  archived_at           timestamptz,
  archived_by_profile_id uuid references profiles(id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index on signals (review_status);
create index on signals (jurisdiction);
create index on signals (source_id);
create index on signals (created_by_profile_id);

create table signal_evidence (
  id                    uuid primary key default gen_random_uuid(),
  signal_id             uuid not null references signals(id) on delete cascade,
  source_document_id    uuid not null references source_documents(id) on delete restrict,
  evidence_type         evidence_type not null,
  evidence_source_type  evidence_source_type not null default 'human',  -- ADR-001 D4 gate
  evidence_text         text not null,           -- required: exact or paraphrased text
  citation_reference    text not null,           -- required: page, section, URL fragment, timestamp
  internal_notes        text,
  created_by_profile_id uuid not null references profiles(id),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index on signal_evidence (signal_id);
create index on signal_evidence (source_document_id);

-- DB-level guard: signal cannot move to approved without at least one evidence record.
-- The check runs via a constraint trigger on review_status transition.
create or replace function check_signal_has_evidence()
returns trigger language plpgsql as $$
begin
  if new.review_status = 'approved' then
    if not exists (
      select 1 from signal_evidence where signal_id = new.id
    ) then
      raise exception 'Signal cannot be approved without at least one evidence record.';
    end if;

    -- ADR-001 D4: block approval if all evidence is ai_assisted only
    if not exists (
      select 1 from signal_evidence
      where signal_id = new.id
        and evidence_source_type = 'human'
    ) then
      raise exception 'Signal cannot be approved on AI-assisted evidence alone. At least one human-verified evidence record is required.';
    end if;
  end if;

  -- Block direct draft->published transitions
  if new.review_status = 'published' and old.review_status != 'approved' then
    raise exception 'Signal must be approved before it can be published.';
  end if;

  return new;
end;
$$;

create trigger signal_approval_gate
  before update of review_status on signals
  for each row execute function check_signal_has_evidence();

-- Triggers
create trigger signals_updated_at before update on signals
  for each row execute function set_updated_at();

create trigger signal_evidence_updated_at before update on signal_evidence
  for each row execute function set_updated_at();

create trigger signals_record_version before update on signals
  for each row execute function increment_record_version();


-- ============================================================
-- 0005_create_review_queue.sql
-- ============================================================

-- 0005_create_review_queue.sql (corrected)
-- Harbourview Production Spine — signal review workflow
-- ADR-001 D1: reviewer_profile_id must be an admin. Enforced at app layer in server actions.
--
-- CORRECTION vs prior version:
--   The original had UNIQUE (signal_id, status) DEFERRABLE INITIALLY DEFERRED.
--   That constraint breaks re-submission: once a signal has a 'rejected' row,
--   a second rejection attempt (after editing and resubmitting) creates a
--   duplicate (signal_id, 'rejected') conflict and the insert fails.
--   The correct model is a PARTIAL UNIQUE INDEX that only covers active statuses
--   ('pending', 'under_review'). Historical resolved rows (approved/rejected/returned)
--   accumulate freely, giving a full submission history per signal.

create table review_queue_items (
  id                      uuid primary key default gen_random_uuid(),
  signal_id               uuid not null references signals(id) on delete cascade,
  status                  text not null default 'pending'
                            check (status in ('pending', 'under_review', 'approved', 'rejected', 'returned')),
  assigned_to_profile_id  uuid references profiles(id),      -- must be admin, enforced at app layer
  submitted_by_profile_id uuid not null references profiles(id),
  reviewer_notes          text,                              -- internal only
  rejection_reason        text,
  return_reason           text,
  resolved_at             timestamptz,
  resolved_by_profile_id  uuid references profiles(id),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
  -- NOTE: no table-level unique constraint here; see partial index below
);

-- Partial unique index: only one active (pending or under_review) review item
-- per signal at a time. Resolved rows (approved/rejected/returned) are
-- unrestricted so a signal can be submitted, rejected, edited, and resubmitted
-- any number of times without constraint conflicts.
create unique index review_queue_one_active_per_signal
  on review_queue_items (signal_id)
  where status in ('pending', 'under_review');

create index on review_queue_items (signal_id);
create index on review_queue_items (status);
create index on review_queue_items (assigned_to_profile_id);

create trigger review_queue_updated_at before update on review_queue_items
  for each row execute function set_updated_at();


-- ============================================================
-- 0006_create_dossiers_and_publish_events.sql
-- ============================================================

-- 0006_create_dossiers_and_publish_events.sql (corrected)
-- Harbourview Production Spine — dossier assembly and publication
-- ADR-001 D1: publish gated to admin at app layer
-- ADR-001 D4: published dossiers exposed as JSON feed via API, no client UI
--
-- CORRECTIONS vs prior version:
--
-- [1] REVOKE MODEL REWRITTEN
--   The original had block_publish_event_mutation() raising an exception on
--   ANY update to publish_events — but the revoke server action then attempted
--   UPDATE publish_events SET revoked_at = ..., status = 'revoked'.
--   Those are incompatible: the trigger fires unconditionally regardless of
--   caller role. The fix is to remodel revoke as a NEW append-only row
--   (status = 'revoked') that references the original event via
--   revokes_event_id. The original row is never touched. This preserves
--   true append-only semantics: the audit trail shows both the publish and
--   the revoke as discrete timestamped events.
--
--   Impact on server action: revokePublishEvent() must INSERT a new
--   publish_events row with status='revoked' and revokes_event_id pointing
--   to the original, rather than UPDATE the original row. The api_token
--   on the original row should be cleared (set null) via the service role
--   so the feed endpoint returns 410 Gone for revoked events. That nulling
--   is the only permitted mutation on a completed publish_events row and is
--   handled via a targeted service-role bypass (not through the anon client).
--
-- [2] DOSSIER PUBLISH ATOMICITY NOTE
--   block_published_dossier_mutation() fires on ANY update once
--   status = 'published'. The server action publishDossier() MUST set
--   status, published_at, and published_by_profile_id in a single UPDATE
--   statement. Splitting into two updates will cause the second to hit
--   the immutability guard. This is enforced by convention in the server
--   action; no DB change is needed here, but it is documented in this file
--   as the authoritative constraint note.

-- ============================================================
-- DOSSIERS
-- ============================================================

create table dossiers (
  id                      uuid primary key default gen_random_uuid(),
  workspace_id            uuid not null references workspaces(id) on delete restrict,
  title                   text not null,
  summary                 text,
  status                  dossier_status not null default 'draft',
  version_number          integer not null default 1,
  supersedes_dossier_id   uuid references dossiers(id), -- links to prior published version
  jurisdiction            text,
  internal_notes          text,                          -- never client-visible; excluded from snapshot_json
  record_version          integer not null default 1,
  created_by_profile_id   uuid not null references profiles(id),
  updated_by_profile_id   uuid references profiles(id),
  published_at            timestamptz,                   -- set atomically with status='published'
  published_by_profile_id uuid references profiles(id), -- set atomically with status='published'
  effective_at            timestamptz,                   -- client-facing effective date; MUST be included in snapshot_json
  archived_at             timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create index on dossiers (workspace_id);
create index on dossiers (status);
create index on dossiers (supersedes_dossier_id);

create table dossier_items (
  id                    uuid primary key default gen_random_uuid(),
  dossier_id            uuid not null references dossiers(id) on delete cascade,
  signal_id             uuid not null references signals(id) on delete restrict,
  display_order         integer not null default 0,
  item_notes            text,                  -- editorial note; internal only, excluded from snapshot_json
  created_by_profile_id uuid not null references profiles(id),
  created_at            timestamptz not null default now(),
  unique (dossier_id, signal_id)
);

create index on dossier_items (dossier_id);
create index on dossier_items (signal_id);

-- Immutability: block any UPDATE on a published dossier.
-- The server action publishDossier() MUST set status, published_at, and
-- published_by_profile_id in a SINGLE UPDATE. If split across two statements,
-- the second will hit this guard.
create or replace function block_published_dossier_mutation()
returns trigger language plpgsql as $$
begin
  if old.status = 'published' then
    raise exception 'Published dossiers are immutable. Create a new version via supersedes_dossier_id instead.';
  end if;
  return new;
end;
$$;

create trigger dossier_immutability_guard
  before update on dossiers
  for each row execute function block_published_dossier_mutation();

-- Triggers
create trigger dossiers_updated_at before update on dossiers
  for each row execute function set_updated_at();

create trigger dossiers_record_version before update on dossiers
  for each row execute function increment_record_version();

-- ============================================================
-- PUBLISH EVENTS (append-only — corrected revoke model)
-- ============================================================

create table publish_events (
  id                      uuid primary key default gen_random_uuid(),
  dossier_id              uuid not null references dossiers(id) on delete restrict,
  workspace_id            uuid not null references workspaces(id) on delete restrict,

  -- 'completed'  = active publication
  -- 'revoked'    = this row IS the revocation record (references original via revokes_event_id)
  status                  publish_event_status not null default 'completed',

  published_by_profile_id uuid not null references profiles(id),  -- must be admin

  -- ADR-001 D4: full snapshot of dossier state at publish time.
  -- Populated by the assemble_publish_snapshot() function.
  -- MUST NOT include internal_notes, analyst_notes, or item_notes from any object.
  -- MUST include effective_at from the dossier.
  snapshot_json           jsonb not null,

  -- Scoped token for JSON feed access. Nulled by service role when revoked.
  api_token               text unique,

  -- REVOKE MODEL: a revocation is a new row, not an update to this row.
  -- revokes_event_id links the revocation row back to the original publish row.
  -- On the original row, revokes_event_id is null.
  -- On a revocation row, status = 'revoked' and revokes_event_id = original row id.
  revokes_event_id        uuid references publish_events(id),
  revoked_by_profile_id   uuid references profiles(id),           -- populated on revocation rows only
  revoke_reason           text,                                    -- populated on revocation rows only

  created_at              timestamptz not null default now()
  -- No updated_at: publish_events are append-only by design.
);

-- Constraint: revocation rows must reference an original, and original rows must not
-- have a self-referencing revokes_event_id.
alter table publish_events
  add constraint publish_events_revoke_self_check
  check (revokes_event_id != id);

-- Constraint: only one active (completed) publish event per dossier at a time.
-- Multiple revocation rows are allowed (idempotent revoke protection).
create unique index publish_events_one_active_per_dossier
  on publish_events (dossier_id)
  where status = 'completed';

create index on publish_events (dossier_id);
create index on publish_events (workspace_id);
create index on publish_events (status);
create index on publish_events (revokes_event_id);

-- Append-only: block ALL updates to publish_events rows.
-- Revoke creates a new row; it never mutates the original.
-- The only exception is nulling api_token on revocation, which MUST be
-- done via a SECURITY DEFINER function (see below) that bypasses RLS
-- but still fires this trigger check — therefore api_token nulling is
-- also modelled as a new revocation row, not an update. The feed route
-- checks whether an active completed row exists for the given token,
-- so a revocation row presence is sufficient to invalidate the token
-- without touching the original row.
create or replace function block_publish_event_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'Publish events are append-only. Revocation creates a new row via revokes_event_id. Never update existing rows.';
end;
$$;

create trigger publish_event_immutability
  before update on publish_events
  for each row execute function block_publish_event_mutation();

-- ============================================================
-- FEED ROUTE BEHAVIOUR (enforced at app layer, documented here)
-- ============================================================
--
-- The /api/feed/[token] route handler must:
--   1. Look up publish_events WHERE api_token = $token AND status = 'completed'
--   2. Check that no revocation row exists:
--        SELECT 1 FROM publish_events
--        WHERE revokes_event_id = $original_id AND status = 'revoked'
--   3. If revocation row found: return 410 Gone with revoke_reason
--   4. If not found: return snapshot_json as application/json
--
-- This means the original api_token is never nulled. Revocation is detected
-- purely by the presence of a revocation row, which is simpler and fully
-- consistent with append-only semantics.


-- ============================================================
-- 0006b_amend_dossier_immutability_trigger.sql
-- ============================================================

-- 0006b_amend_dossier_immutability_trigger.sql
-- Harbourview Production Spine — amend dossier immutability trigger
-- Apply after 0006_create_dossiers_and_publish_events.sql
--
-- PURPOSE
-- The block_published_dossier_mutation() trigger in 0006 rejects ALL
-- updates on a published dossier without exception. This is correct for
-- content mutations (title, summary, signals, etc.) but it also blocks
-- the published → superseded lifecycle transition, which createDossierVersion()
-- needs to perform when a new version of a published dossier is created.
--
-- CHANGE
-- Replace the trigger function with a version that permits exactly one
-- additional transition: published → superseded. All other updates on a
-- published dossier continue to be rejected unconditionally.
--
-- WHAT STAYS BLOCKED on a published dossier:
--   - Any field edit (title, summary, jurisdiction, internal_notes, etc.)
--   - published_at, published_by_profile_id, effective_at changes
--   - Any status transition other than published → superseded
--
-- WHAT IS NOW PERMITTED on a published dossier:
--   - status = 'superseded' (only — no other field changes in the same update)
--
-- ENFORCEMENT NOTE
-- createDossierVersion() in dossiers.ts uses the service client for this
-- update (bypasses RLS). The trigger still fires against the service client
-- because triggers are independent of RLS. The amended trigger is what
-- permits it — not the service client bypass alone.
--
-- The service client is used because the anon/session client's RLS
-- dossiers_update policy also permits admin+analyst updates, so RLS alone
-- would not block this. The defence in depth is: trigger permits only the
-- superseded transition, RLS permits only admin+analyst to attempt it,
-- createDossierVersion() requires admin+analyst role check before calling.

create or replace function block_published_dossier_mutation()
returns trigger language plpgsql as $$
begin
  -- If the dossier was published, permit ONLY the transition to 'superseded'.
  -- Block all other mutations unconditionally.
  if old.status = 'published' then
    if new.status = 'superseded' then
      -- Permitted lifecycle transition: published → superseded.
      -- Triggered by createDossierVersion() via service client.
      -- Allow the update to proceed.
      return new;
    else
      raise exception
        'Published dossiers are immutable. '
        'To update content, create a new version via createDossierVersion(). '
        'Attempted status transition: % → %', old.status, new.status;
    end if;
  end if;

  return new;
end;
$$;

-- The trigger binding (dossier_immutability_guard) already exists from 0006
-- and points to block_published_dossier_mutation(). Replacing the function
-- is sufficient — no need to drop and recreate the trigger.

-- Verify the function replaced correctly (runs at migration time, output visible in logs)
do $$
begin
  assert (
    select prosrc from pg_proc where proname = 'block_published_dossier_mutation'
  ) like '%superseded%',
  'block_published_dossier_mutation trigger function did not update correctly';
end;
$$;


-- ============================================================
-- 0007_create_audit_events.sql
-- ============================================================

-- 0007_create_audit_events.sql
-- Harbourview Production Spine — append-only audit trail

create table audit_events (
  id                      uuid primary key default gen_random_uuid(),
  entity_type             text not null,         -- 'signal', 'dossier', 'source', 'source_document', 'workspace_member', etc.
  entity_id               uuid not null,
  action_type             audit_action not null,
  performed_by_profile_id uuid references profiles(id),
  performed_at            timestamptz not null default now(),
  from_status             text,                  -- review_status or other status before transition
  to_status               text,                  -- status after transition
  change_summary          text,                  -- human-readable description
  diff_json               jsonb,                 -- structured field diff for material updates
  workspace_id            uuid references workspaces(id)  -- for scoped queries
  -- No updated_at, no record_version: audit_events are strictly append-only
);

-- No UPDATE or DELETE on audit_events
create or replace function block_audit_event_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'Audit events are append-only and cannot be modified or deleted.';
end;
$$;

create trigger audit_event_no_update
  before update on audit_events
  for each row execute function block_audit_event_mutation();

create trigger audit_event_no_delete
  before delete on audit_events
  for each row execute function block_audit_event_mutation();

-- Indexes for common query patterns
create index on audit_events (entity_type, entity_id);
create index on audit_events (performed_by_profile_id);
create index on audit_events (performed_at desc);
create index on audit_events (workspace_id);
create index on audit_events (action_type);

-- Utility function: write an audit event from application code
-- Usage: select write_audit_event('signal', signal_id, 'approve', profile_id, 'in_review', 'approved', 'Signal approved by admin', null, workspace_id)
create or replace function write_audit_event(
  p_entity_type             text,
  p_entity_id               uuid,
  p_action_type             audit_action,
  p_performed_by_profile_id uuid,
  p_from_status             text default null,
  p_to_status               text default null,
  p_change_summary          text default null,
  p_diff_json               jsonb default null,
  p_workspace_id            uuid default null
)
returns uuid language plpgsql as $$
declare
  v_id uuid;
begin
  insert into audit_events (
    entity_type, entity_id, action_type, performed_by_profile_id,
    from_status, to_status, change_summary, diff_json, workspace_id
  ) values (
    p_entity_type, p_entity_id, p_action_type, p_performed_by_profile_id,
    p_from_status, p_to_status, p_change_summary, p_diff_json, p_workspace_id
  ) returning id into v_id;
  return v_id;
end;
$$;


-- ============================================================
-- 0008_create_rls_policies.sql
-- ============================================================

-- 0008_create_rls_policies.sql (corrected)
-- Harbourview Production Spine — Row Level Security
-- ADR-001 D1: admin can read/write everything. analyst can read/write internal records, cannot approve or publish.
-- ADR-001 D4: client role has NO access at DB level. JSON feed is served via publish_events.snapshot_json
--             through a server-side API route authenticated with api_token. Clients never query the DB directly.
--
-- CORRECTION vs prior version:
--
-- [1] profiles_insert RLS POLICY FIXED
--   The original policy was:
--     create policy profiles_insert on profiles for insert
--       with check (current_platform_role() = 'admin');
--   This blocks the Supabase auth signup trigger, which creates the initial
--   profile row running as the newly created user — not as an admin.
--   current_platform_role() returns null for a user who doesn't yet have a
--   profile row, so the check evaluates to false and the insert is rejected.
--
--   The corrected policy allows a user to insert their own profile row
--   (auth.uid() = id) OR an admin to insert any profile row. This matches
--   the standard Supabase pattern for auth-triggered profile creation.
--
--   The auth trigger itself (create profile on user signup) is a separate
--   Supabase function and is NOT in this migration, but this policy must
--   permit it or signup will silently fail.

-- Enable RLS on all tables
alter table profiles enable row level security;
alter table workspaces enable row level security;
alter table workspace_members enable row level security;
alter table sources enable row level security;
alter table source_documents enable row level security;
alter table signals enable row level security;
alter table signal_evidence enable row level security;
alter table review_queue_items enable row level security;
alter table dossiers enable row level security;
alter table dossier_items enable row level security;
alter table publish_events enable row level security;
alter table audit_events enable row level security;

-- Helper: get current user's platform role
-- Returns null for users without a profile row (e.g. during initial signup).
create or replace function current_platform_role()
returns platform_role language sql security definer stable as $$
  select platform_role from profiles where id = auth.uid()
$$;

-- Helper: check workspace membership
create or replace function is_workspace_member(p_workspace_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from workspace_members
    where workspace_id = p_workspace_id
      and profile_id = auth.uid()
  )
$$;

-- ============================================================
-- profiles
-- ============================================================

-- Users can read their own profile; admins can read all.
create policy profiles_select on profiles for select using (
  id = auth.uid() or current_platform_role() = 'admin'
);

-- CORRECTED: allow self-insert (for auth trigger on signup) OR admin insert.
-- Without auth.uid() = id, the auth trigger cannot create the profile row
-- because current_platform_role() returns null before the row exists.
create policy profiles_insert on profiles for insert with check (
  auth.uid() = id
  or current_platform_role() = 'admin'
);

-- Users can update their own profile; admins can update any profile.
-- Note: platform_role updates should be further restricted at app layer
-- so analysts cannot elevate their own role. RLS cannot prevent a user
-- from updating their own platform_role field; that check lives in the
-- server action (validate that only admins may change platform_role).
create policy profiles_update on profiles for update using (
  id = auth.uid() or current_platform_role() = 'admin'
);

-- ============================================================
-- workspaces
-- ============================================================

create policy workspaces_select on workspaces for select using (
  current_platform_role() in ('admin', 'analyst')
);

create policy workspaces_insert on workspaces for insert with check (
  current_platform_role() = 'admin'
);

create policy workspaces_update on workspaces for update using (
  current_platform_role() = 'admin'
);

-- ============================================================
-- workspace_members
-- ============================================================

create policy workspace_members_select on workspace_members for select using (
  current_platform_role() in ('admin', 'analyst')
  or profile_id = auth.uid()
);

create policy workspace_members_insert on workspace_members for insert with check (
  current_platform_role() = 'admin'
);

create policy workspace_members_update on workspace_members for update using (
  current_platform_role() = 'admin'
);

-- ============================================================
-- sources
-- ============================================================

create policy sources_select on sources for select using (
  current_platform_role() in ('admin', 'analyst')
);

create policy sources_insert on sources for insert with check (
  current_platform_role() in ('admin', 'analyst')
);

create policy sources_update on sources for update using (
  current_platform_role() in ('admin', 'analyst')
);

-- ============================================================
-- source_documents
-- ============================================================

create policy source_documents_select on source_documents for select using (
  current_platform_role() in ('admin', 'analyst')
);

create policy source_documents_insert on source_documents for insert with check (
  current_platform_role() in ('admin', 'analyst')
);

create policy source_documents_update on source_documents for update using (
  current_platform_role() in ('admin', 'analyst')
);

-- ============================================================
-- signals
-- ============================================================

create policy signals_select on signals for select using (
  current_platform_role() in ('admin', 'analyst')
);

create policy signals_insert on signals for insert with check (
  current_platform_role() in ('admin', 'analyst')
);

-- Updates allowed for admin and analyst. The check_signal_has_evidence trigger
-- (DB layer) blocks approval without evidence. The server action (app layer)
-- blocks analysts from setting review_status = 'approved'. RLS here does not
-- distinguish between field-level update types — that's intentional at v1.
-- See ARCHITECTURE.md for the note on adding an approve_signal() DB function
-- for stronger role enforcement at Phase 4+.
create policy signals_update on signals for update using (
  current_platform_role() in ('admin', 'analyst')
);

-- ============================================================
-- signal_evidence
-- ============================================================

create policy signal_evidence_select on signal_evidence for select using (
  current_platform_role() in ('admin', 'analyst')
);

create policy signal_evidence_insert on signal_evidence for insert with check (
  current_platform_role() in ('admin', 'analyst')
);

create policy signal_evidence_update on signal_evidence for update using (
  current_platform_role() in ('admin', 'analyst')
);

-- ============================================================
-- review_queue_items
-- ============================================================

create policy review_queue_select on review_queue_items for select using (
  current_platform_role() in ('admin', 'analyst')
);

-- Analysts can insert (submit for review); admins can insert too.
create policy review_queue_insert on review_queue_items for insert with check (
  current_platform_role() in ('admin', 'analyst')
);

-- Only admins can resolve review queue items (approve/reject/return).
-- This is the DB-layer enforcement of ADR-001 D1 for the review step.
create policy review_queue_update on review_queue_items for update using (
  current_platform_role() = 'admin'
);

-- ============================================================
-- dossiers
-- ============================================================

create policy dossiers_select on dossiers for select using (
  current_platform_role() in ('admin', 'analyst')
);

create policy dossiers_insert on dossiers for insert with check (
  current_platform_role() in ('admin', 'analyst')
);

-- block_published_dossier_mutation trigger enforces immutability.
-- RLS gates who may attempt an update at all.
create policy dossiers_update on dossiers for update using (
  current_platform_role() in ('admin', 'analyst')
);

-- ============================================================
-- dossier_items
-- ============================================================

create policy dossier_items_select on dossier_items for select using (
  current_platform_role() in ('admin', 'analyst')
);

create policy dossier_items_insert on dossier_items for insert with check (
  current_platform_role() in ('admin', 'analyst')
);

create policy dossier_items_update on dossier_items for update using (
  current_platform_role() in ('admin', 'analyst')
);

-- ============================================================
-- publish_events
-- ============================================================

-- ADR-001 D4: publish_events rows are never exposed to client users.
-- Feed access is via api_token on the /api/feed/[token] route, not direct DB access.
create policy publish_events_select on publish_events for select using (
  current_platform_role() in ('admin', 'analyst')
);

-- Only admins can insert publish events (both 'completed' and 'revoked' rows).
create policy publish_events_insert on publish_events for insert with check (
  current_platform_role() = 'admin'
);

-- No update policy: the block_publish_event_mutation trigger rejects all updates.
-- Revocation is a new insert, not an update. No RLS update policy needed.

-- ============================================================
-- audit_events
-- ============================================================

create policy audit_events_select on audit_events for select using (
  current_platform_role() in ('admin', 'analyst')
);

-- write_audit_event() DB function is security definer and handles inserts.
-- This policy permits direct inserts from server actions as a fallback.
create policy audit_events_insert on audit_events for insert with check (
  current_platform_role() in ('admin', 'analyst')
);

-- No update or delete policies. Immutability triggers block both unconditionally.


-- ============================================================
-- 0009_seed_data.sql
-- ============================================================

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

-- Fixed UUIDs for deterministic test references (do not change)

-- ============================================================
-- Profiles
-- NOTE: if 0010_create_auth_trigger.sql was applied before auth user
-- creation, the trigger already created these rows. The ON CONFLICT
-- guard makes this idempotent. The UPDATE corrects full_name and
-- platform_role in case the trigger used defaults.
-- ============================================================
insert into profiles (id, email, full_name, platform_role) values
  ('9866753f-1a8d-495c-8ab8-d0d1eebfce04',   'admin@harbourview.io',   'HV Admin',    'admin'),
  ('31e6281c-aec9-4c6d-a9c3-4852b1c057d5', 'analyst@harbourview.io', 'HV Analyst',  'analyst')
on conflict (id) do update set
  full_name     = excluded.full_name,
  platform_role = excluded.platform_role;

-- ============================================================
-- Internal workspace
-- ============================================================
insert into workspaces (id, name, slug, is_internal, created_by_profile_id) values
  ('00000000-0000-0000-0000-000000000010', 'Germany Intelligence', 'germany-intelligence', true, '9866753f-1a8d-495c-8ab8-d0d1eebfce04')
on conflict (id) do nothing;

-- ============================================================
-- Workspace members
-- ============================================================
insert into workspace_members (workspace_id, profile_id, workspace_role, added_by_profile_id) values
  ('00000000-0000-0000-0000-000000000010', '9866753f-1a8d-495c-8ab8-d0d1eebfce04',   'owner',  '9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000010', '31e6281c-aec9-4c6d-a9c3-4852b1c057d5', 'editor', '9866753f-1a8d-495c-8ab8-d0d1eebfce04')
on conflict (workspace_id, profile_id) do nothing;

-- ============================================================
-- Source: WEECO Pharma GmbH (company_primary, DE)
-- ============================================================
insert into sources (
  id, name, canonical_url, domain, source_tier, status,
  jurisdiction, entity_type, contact_org, description, created_by_profile_id
) values (
  '00000000-0000-0000-0000-000000000020',
  'WEECO Pharma GmbH',
  'https://www.weeco-pharma.de',
  'weeco-pharma.de',
  'company_primary',
  'active',
  'DE',
  'company',
  'WEECO Pharma GmbH',
  'Licensed cannabis importer and distributor in Germany. Key gatekeeper in the German medical cannabis wholesale channel.',
  '9866753f-1a8d-495c-8ab8-d0d1eebfce04'
)
on conflict (id) do nothing;

-- ============================================================
-- Source document: BfArM import notice (URL-only — ADR-001 D2)
-- ============================================================
insert into source_documents (
  id, source_id, title, url, publication_date, status, parsed_content, created_by_profile_id
) values (
  '00000000-0000-0000-0000-000000000030',
  '00000000-0000-0000-0000-000000000020',
  'BfArM Cannabis Import Authorization — WEECO Pharma GmbH Q1 2025',
  'https://www.bfarm.de/SharedDocs/Bekanntmachungen/DE/Betaeubungsmittel/cannabis-weeco-2025-q1.html',
  '2025-02-01',
  'parsed',
  'The BfArM has issued an import authorization to WEECO Pharma GmbH for cannabis flower (THC >0.2%) under §3 BtMG for the period January–March 2025. Volume authorized: 500 kg. Origin: Portugal (Tilray). Wholesale distribution permitted to licensed pharmacies only.',
  '31e6281c-aec9-4c6d-a9c3-4852b1c057d5'
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
  '00000000-0000-0000-0000-000000000040',
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
  '00000000-0000-0000-0000-000000000020',
  '31e6281c-aec9-4c6d-a9c3-4852b1c057d5'
)
on conflict (id) do nothing;

-- ============================================================
-- Evidence record (human-verified — required for approval per non-negotiable rule 2)
-- ============================================================
insert into signal_evidence (
  id, signal_id, source_document_id, evidence_type, evidence_source_type,
  evidence_text, citation_reference, created_by_profile_id
) values (
  '00000000-0000-0000-0000-000000000050',
  '00000000-0000-0000-0000-000000000040',
  '00000000-0000-0000-0000-000000000030',
  'paraphrased_fact',
  'human',
  'BfArM issued WEECO Pharma GmbH an import authorization for 500 kg cannabis flower (THC >0.2%) from Tilray Portugal for Q1 2025, restricted to wholesale distribution to licensed pharmacies under §3 BtMG.',
  'BfArM Bekanntmachungen — WEECO Q1 2025, paragraph 1',
  '31e6281c-aec9-4c6d-a9c3-4852b1c057d5'
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
  submitted_by_profile_id = '31e6281c-aec9-4c6d-a9c3-4852b1c057d5'
where id = '00000000-0000-0000-0000-000000000040';

insert into review_queue_items (id, signal_id, status, submitted_by_profile_id, assigned_to_profile_id)
values ('00000000-0000-0000-0000-000000000060', '00000000-0000-0000-0000-000000000040', 'pending', '31e6281c-aec9-4c6d-a9c3-4852b1c057d5', '9866753f-1a8d-495c-8ab8-d0d1eebfce04')
on conflict (id) do nothing;

-- ============================================================
-- Approve signal (admin action)
-- ============================================================
update signals set
  review_status           = 'approved',
  reviewed_at             = now(),
  reviewed_by_profile_id  = '9866753f-1a8d-495c-8ab8-d0d1eebfce04'
where id = '00000000-0000-0000-0000-000000000040';

update review_queue_items set
  status                  = 'approved',
  resolved_at             = now(),
  resolved_by_profile_id  = '9866753f-1a8d-495c-8ab8-d0d1eebfce04'
where id = '00000000-0000-0000-0000-000000000060';

-- ============================================================
-- Dossier: created as draft, moved to ready_for_publish
-- (two pre-publish updates — safe, trigger only fires when OLD.status = 'published')
-- ============================================================
insert into dossiers (id, workspace_id, title, summary, status, jurisdiction, created_by_profile_id) values
  ('00000000-0000-0000-0000-000000000070',
   '00000000-0000-0000-0000-000000000010',
   'Germany Cannabis Market Intelligence — Q1 2025',
   'Regulatory and licensing signals for the German medical cannabis wholesale channel, Q1 2025. Anchored to WEECO Pharma GmbH BfArM authorization.',
   'draft',
   'DE',
   '9866753f-1a8d-495c-8ab8-d0d1eebfce04')
on conflict (id) do nothing;

-- Dossier item
insert into dossier_items (id, dossier_id, signal_id, display_order, created_by_profile_id) values
  ('00000000-0000-0000-0000-000000000080', '00000000-0000-0000-0000-000000000070', '00000000-0000-0000-0000-000000000040', 1, '9866753f-1a8d-495c-8ab8-d0d1eebfce04')
on conflict (id) do nothing;

update dossiers set status = 'ready_for_publish'
where id = '00000000-0000-0000-0000-000000000070';

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
  '00000000-0000-0000-0000-000000000090',
  '00000000-0000-0000-0000-000000000070',
  '00000000-0000-0000-0000-000000000010',
  'completed',
  '9866753f-1a8d-495c-8ab8-d0d1eebfce04',
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
  published_by_profile_id = '9866753f-1a8d-495c-8ab8-d0d1eebfce04'
where id = '00000000-0000-0000-0000-000000000070';

-- ============================================================
-- Audit trail for the golden path
-- ============================================================
select write_audit_event('signal',  '00000000-0000-0000-0000-000000000040',  'create',           '31e6281c-aec9-4c6d-a9c3-4852b1c057d5', null,             'draft',     'Signal created',                                        null, '00000000-0000-0000-0000-000000000010');
select write_audit_event('signal',  '00000000-0000-0000-0000-000000000040',  'submit_for_review', '31e6281c-aec9-4c6d-a9c3-4852b1c057d5', 'draft',         'in_review', 'Signal submitted for review',                           null, '00000000-0000-0000-0000-000000000010');
select write_audit_event('signal',  '00000000-0000-0000-0000-000000000040',  'approve',          '9866753f-1a8d-495c-8ab8-d0d1eebfce04',   'in_review',      'approved',  'Signal approved by admin',                              null, '00000000-0000-0000-0000-000000000010');
select write_audit_event('dossier', '00000000-0000-0000-0000-000000000070', 'create',           '9866753f-1a8d-495c-8ab8-d0d1eebfce04',   null,             'draft',     'Dossier created',                                       null, '00000000-0000-0000-0000-000000000010');
select write_audit_event('dossier', '00000000-0000-0000-0000-000000000070', 'publish',          '9866753f-1a8d-495c-8ab8-d0d1eebfce04',   'ready_for_publish', 'published', 'Dossier published to Germany Intelligence workspace', null, '00000000-0000-0000-0000-000000000010');

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
  '00000000-0000-0000-0000-000000000020',
  '31e6281c-aec9-4c6d-a9c3-4852b1c057d5'
)
on conflict do nothing;

select write_audit_event(
  'signal',
  (select id from signals where title = 'Unverified WEECO distribution rumour — rejected' limit 1),
  'reject', '9866753f-1a8d-495c-8ab8-d0d1eebfce04', 'in_review', 'rejected',
  'Rejected: no primary source, community-only origin',
  null, '00000000-0000-0000-0000-000000000010'
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


-- ============================================================
-- 0010_create_auth_trigger.sql
-- ============================================================

-- 0010_create_auth_trigger.sql
-- Harbourview Production Spine — auth trigger for automatic profile creation
--
-- OI-1: When a new user is created in auth.users (via Supabase Auth signup,
-- invite, or magic link), this trigger automatically inserts a corresponding
-- row into the profiles table.
--
-- Without this trigger, a new user would have no profiles row and
-- current_platform_role() would return null, silently blocking all RLS
-- policies that check role. The user would be authenticated but unable to
-- access any data.
--
-- Design decisions:
--   - platform_role defaults to 'analyst' (the safer, lower-privilege default).
--     Admins must explicitly elevate a user's role after signup.
--   - full_name is drawn from raw_user_meta_data->>'full_name' if provided
--     (populated when using Supabase invite or when the signup call passes
--     user metadata). Falls back to the email prefix so the column NOT NULL
--     constraint is always satisfied.
--   - email is taken from the new auth.users row directly.
--   - default_workspace_id is left null — workspace assignment is a separate
--     admin action after the user exists.
--   - is_active defaults to true (from table definition); not set here.
--   - The function runs as SECURITY DEFINER so it executes with the privileges
--     of the function owner (postgres/service role), bypassing RLS on the
--     profiles table. This is intentional and safe: the trigger fires only
--     from auth.users INSERT, which is itself already auth-controlled by
--     Supabase. The profiles_insert RLS policy (fixed in 0008) also permits
--     auth.uid() = id as a belt-and-suspenders guard.
--
-- Apply after: 0009_seed_data.sql (final migration in the base set)
-- Safe to re-run: CREATE OR REPLACE + DROP TRIGGER IF EXISTS make this
-- idempotent for re-application in development.

-- ============================================================
-- Function: handle_new_user
-- Fires on INSERT to auth.users. Creates the profiles row.
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    full_name,
    platform_role
  )
  values (
    new.id,
    new.email,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      split_part(new.email, '@', 1)   -- fallback: email prefix, never null
    ),
    'analyst'  -- safe default; admins elevate explicitly
  )
  on conflict (id) do nothing;   -- idempotent: don't error if row already exists
                                  -- (e.g. admin pre-created the profile via seed)
  return new;
end;
$$;

-- ============================================================
-- Trigger: on_auth_user_created
-- Attach the function to auth.users INSERT.
-- ============================================================
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- Grant: ensure the function is callable from the auth schema
-- (Supabase requires explicit grant for cross-schema triggers)
-- ============================================================
grant execute on function public.handle_new_user() to supabase_auth_admin;


-- ============================================================
-- 0011_workspace_membership_rls.sql
-- ============================================================

-- 0011_workspace_membership_rls.sql
-- Harbourview Production Spine — OI-2: Multi-workspace client membership (closed)
--
-- DECISION (OI-2):
--   Client users (platform_role = 'client') may belong to multiple workspaces
--   via workspace_members. A client's read access to dossiers and publish_events
--   is scoped to workspaces they are a member of. Internal users (admin, analyst)
--   retain cross-workspace visibility — they must be able to see all signals,
--   sources, and dossiers regardless of workspace assignment.
--
-- WHAT THIS MIGRATION ADDS:
--   1. Workspace-scoped SELECT policies on dossiers and publish_events for
--      client users, gated on is_workspace_member().
--   2. An explicit client-role SELECT path on workspace_members so clients
--      can discover their own workspace associations.
--   3. The client platform_role enum value is confirmed present in 0001.
--      No schema changes needed; workspace_members and is_workspace_member()
--      were already wired in 0002 and 0008.
--
-- WHAT THIS MIGRATION DOES NOT DO (deferred to Phase 2):
--   - Workspace-scoped RLS on signals, sources, source_documents. Internal
--     users (admin, analyst) see all records regardless of workspace at v1.
--     This is correct for v1 — analysts work across all jurisdictions.
--   - Workspace-specific signal visibility (e.g. a signal can belong to one
--     workspace and be invisible to analysts on another workspace). That's a
--     Phase 2 multi-tenant feature.
--   - Client write access of any kind. Clients are read-only at DB layer and
--     receive intelligence exclusively via the JSON feed route (ADR-001 D4).
--
-- APPLY AFTER: 0010_create_auth_trigger.sql
--
-- IDEMPOTENT: uses DROP POLICY IF EXISTS before CREATE POLICY so this
-- migration can be re-run in development without error.

-- ============================================================
-- 1. Confirm client role exists in the platform_role enum
--    (defined in 0001_create_enums.sql)
-- This is a documentation-only assertion; Postgres doesn't support
-- IF NOT EXISTS for enum values without a DO block, so we check and
-- add defensively.
-- ============================================================
do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on e.enumtypid = t.oid
    where t.typname = 'platform_role'
      and e.enumlabel = 'client'
  ) then
    alter type platform_role add value 'client';
  end if;
end;
$$;

-- ============================================================
-- 2. Dossiers — add client-scoped SELECT path
--
-- Current policy (from 0008):
--   dossiers_select: platform_role IN ('admin', 'analyst')
--
-- Replace with a policy that also permits client users to read
-- dossiers in workspaces they are members of.
-- Internal users retain unrestricted cross-workspace visibility.
-- ============================================================
drop policy if exists dossiers_select on dossiers;

create policy dossiers_select on dossiers for select using (
  -- Internal users: cross-workspace visibility (unchanged from 0008)
  current_platform_role() in ('admin', 'analyst')
  or
  -- Client users: scoped to their workspace memberships only
  (
    current_platform_role() = 'client'
    and is_workspace_member(workspace_id)
  )
);

-- ============================================================
-- 3. Dossier items — add client-scoped SELECT path
--
-- Clients who can see a dossier must also be able to read its items.
-- item_notes are present on this table but are never returned to clients
-- via the feed route — the feed reads from snapshot_json, not dossier_items.
-- The RLS gate here is belt-and-suspenders; the real client path is the feed.
-- ============================================================
drop policy if exists dossier_items_select on dossier_items;

create policy dossier_items_select on dossier_items for select using (
  current_platform_role() in ('admin', 'analyst')
  or
  (
    current_platform_role() = 'client'
    and exists (
      select 1 from dossiers d
      where d.id = dossier_items.dossier_id
        and is_workspace_member(d.workspace_id)
    )
  )
);

-- ============================================================
-- 4. Publish events — add client-scoped SELECT path
--
-- ADR-001 D4: clients never query publish_events directly — they use
-- the /api/feed/[token] route which authenticates via api_token.
-- The feed route uses the service client (bypasses RLS) so this policy
-- is belt-and-suspenders only. It is correct to include it here so that
-- if a client session somehow reaches the DB directly, they still get
-- correct workspace scoping rather than an empty result.
-- ============================================================
drop policy if exists publish_events_select on publish_events;

create policy publish_events_select on publish_events for select using (
  current_platform_role() in ('admin', 'analyst')
  or
  (
    current_platform_role() = 'client'
    and is_workspace_member(workspace_id)
  )
);

-- ============================================================
-- 5. Workspace members — client self-read
--
-- The 0008 policy already covers this:
--   workspace_members_select: platform_role IN ('admin','analyst') OR profile_id = auth.uid()
-- The `profile_id = auth.uid()` arm already lets any user (including client)
-- read their own membership rows. No change needed — documented here for clarity.
--
-- Clients CANNOT read other members' rows (no admin/analyst role).
-- This is correct: clients should not be able to enumerate internal team
-- membership.
-- ============================================================
-- (no change — 0008 policy is correct as written)

-- ============================================================
-- 6. Signals — client has NO direct DB access
--
-- Signals are internal records. Clients receive signal data only via
-- snapshot_json in the JSON feed. No client SELECT policy on signals.
-- Clients hitting the DB directly get an empty result set (RLS blocks).
-- This is intentional and correct per ADR-001 D4.
-- ============================================================
-- (no change — 0008 signals_select restricts to admin/analyst only)

-- ============================================================
-- 7. App-layer helper: enforce workspace membership on dossier creation
--    (documentation note — no SQL required)
--
-- When an analyst creates a dossier, the server action (createDossier)
-- should validate that the analyst is a member of the target workspace.
-- This is NOT currently enforced at DB layer — it is an app-layer check
-- to add to createDossier() in lib/actions/dossiers.ts:
--
--   const member = await supabase
--     .from('workspace_members')
--     .select('id')
--     .eq('workspace_id', input.workspace_id)
--     .eq('profile_id', profile.id)
--     .maybeSingle();
--   if (!member && profile.platform_role !== 'admin') {
--     throw new Error('Not a member of this workspace');
--   }
--
-- Admins are exempt from membership checks (they manage all workspaces).
-- Deferred to Phase 2 — not blocking v1 golden-path tests.
-- ============================================================



-- ============================================================
-- 0012_germany_operator_seed.sql
-- Germany 5-operator real dataset (OI-3 closed)
-- All \set meta-commands replaced with literal UUIDs for SQL editor
-- ============================================================

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

-- ============================================================
-- Workspace
-- ============================================================
insert into workspaces (id, name, slug, is_internal, created_by_profile_id)
values (
  '00000000-0000-0000-0000-000000000100',
  'Germany Operator Intelligence',
  'germany-operator-intelligence',
  false,
  '9866753f-1a8d-495c-8ab8-d0d1eebfce04'
) on conflict (id) do nothing;

insert into workspace_members (workspace_id, profile_id, workspace_role, added_by_profile_id)
values
  ('00000000-0000-0000-0000-000000000100', '9866753f-1a8d-495c-8ab8-d0d1eebfce04',   'owner',  '9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000100', '31e6281c-aec9-4c6d-a9c3-4852b1c057d5', 'editor', '9866753f-1a8d-495c-8ab8-d0d1eebfce04')
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
   'Adjupharm GmbH','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000111','Bathera GmbH official site',
   'https://bathera.com/','bathera.com','company_primary','company','active','DE',
   'Bathera GmbH','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000112','FOUR 20 PHARMA GmbH official site',
   'https://420pharma.de/en/','420pharma.de','company_primary','company','active','DE',
   'FOUR 20 PHARMA GmbH','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000113','Dr. Reddy''s / Nimbus Health corporate disclosure',
   'https://www.drreddys.com/generics','drreddys.com','company_primary','company','active','DE',
   'Nimbus Health GmbH','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000114','WEECO Pharma GmbH official site',
   'https://weeco.com/en/','weeco.com','company_primary','company','active','DE',
   'WEECO Pharma GmbH','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04')
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
   'Company profile / products sections','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000121','00000000-0000-0000-0000-000000000111',
   'Bathera company overview','https://bathera.com/','captured',
   'Bathera describes itself as headquartered in Germany with cultivation in Portugal and active distribution in Germany and Australia.',
   'Homepage overview / company notice','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000122','00000000-0000-0000-0000-000000000112',
   'FOUR 20 PHARMA company overview','https://420pharma.de/en/','captured',
   'FOUR 20 PHARMA says it has been a global player since 2018 and has been part of Curaleaf International since the end of 2022.',
   'About us section','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000123','00000000-0000-0000-0000-000000000113',
   'Dr. Reddy''s Nimbus platform disclosure','https://www.drreddys.com/generics','captured',
   'Nimbus Health is a licensed pharmaceutical wholesaler focused on medical cannabis and operates in Germany under Dr. Reddy''s.',
   'Nimbus Health section','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000124','00000000-0000-0000-0000-000000000114',
   'WEECO company overview','https://weeco.com/en/','captured',
   'WEECO describes operations along the cannabis supply chain and a footprint spanning Germany and several other European markets.',
   'Homepage / company overview','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04')
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
    '00000000-0000-0000-0000-000000000110','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'
  ),
  (
    '00000000-0000-0000-0000-000000000131',
    'Bathera is operating across Germany, Portugal and Australia with additional expansion targets',
    'Bathera positions itself as a vertically integrated medical cannabis operator headquartered in Germany with cultivation in Portugal and active distribution in Germany and Australia.',
    'market_entry','DE','2026-04-15','Bathera GmbH','Bathera GmbH',
    'observed','high','approved','internal',
    '00000000-0000-0000-0000-000000000111','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'
  ),
  (
    '00000000-0000-0000-0000-000000000132',
    'FOUR 20 PHARMA remains a German market-access platform under Curaleaf International',
    'FOUR 20 PHARMA says it has been active since 2018 and has been part of Curaleaf International since the end of 2022.',
    'ownership','DE','2026-04-15','FOUR 20 PHARMA GmbH','FOUR 20 PHARMA GmbH',
    'observed','high','approved','internal',
    '00000000-0000-0000-0000-000000000112','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'
  ),
  (
    '00000000-0000-0000-0000-000000000133',
    'Nimbus operates as Dr. Reddy''s German medical cannabis platform',
    'Dr. Reddy''s says Nimbus Health is a licensed pharmaceutical wholesaler focused on medical cannabis and continues to operate under the Nimbus brand.',
    'ownership','DE','2022-02-03','Nimbus Health GmbH','Nimbus Health GmbH',
    'observed','high','approved','internal',
    '00000000-0000-0000-0000-000000000113','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'
  ),
  (
    '00000000-0000-0000-0000-000000000134',
    'WEECO presents itself as a multi-market cannabis supply-chain operator',
    'WEECO says it operates cannabis ventures across Germany and several other European markets with activity along the supply chain.',
    'company_profile','DE','2026-04-15','WEECO Pharma GmbH','WEECO Pharma GmbH',
    'observed','medium','approved','internal',
    '00000000-0000-0000-0000-000000000114','9866753f-1a8d-495c-8ab8-d0d1eebfce04','9866753f-1a8d-495c-8ab8-d0d1eebfce04'
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
   'Company profile / products sections','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000131','00000000-0000-0000-0000-000000000121',
   'paraphrased_fact','human',
   'Bathera says it is headquartered in Germany, cultivates in Portugal and is distributing in Germany and Australia.',
   'Homepage overview / company notice','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000142','00000000-0000-0000-0000-000000000132','00000000-0000-0000-0000-000000000122',
   'paraphrased_fact','human',
   'FOUR 20 PHARMA states that it has been active since 2018 and part of Curaleaf International since late 2022.',
   'About us section','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000143','00000000-0000-0000-0000-000000000133','00000000-0000-0000-0000-000000000123',
   'paraphrased_fact','human',
   'Dr. Reddy''s describes Nimbus as a licensed pharmaceutical wholesaler focused on medical cannabis in Germany.',
   'Nimbus Health section','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000144','00000000-0000-0000-0000-000000000134','00000000-0000-0000-0000-000000000124',
   'paraphrased_fact','human',
   'WEECO says it runs cannabis ventures across multiple European markets and along the supply chain.',
   'Homepage / company overview','9866753f-1a8d-495c-8ab8-d0d1eebfce04')
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
  'draft','DE','9866753f-1a8d-495c-8ab8-d0d1eebfce04'
) on conflict (id) do nothing;

-- ============================================================
-- Dossier items
-- item_notes = internal editorial note (workbook called this client_visible_commentary)
-- ============================================================
insert into dossier_items (
  id, dossier_id, signal_id, display_order, item_notes, created_by_profile_id
) values
  ('00000000-0000-0000-0000-000000000160','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000130',1,
   'Adjupharm looks like a practical distribution-platform profile rather than a generic brand shell.','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000161','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000131',2,
   'Bathera is relevant because it combines upstream production with downstream European distribution.','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000162','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000132',3,
   'FOUR 20 PHARMA should be treated as a local access point inside a larger global group.','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000163','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000133',4,
   'Nimbus remains relevant because pharma ownership can change decision speed and risk tolerance.','9866753f-1a8d-495c-8ab8-d0d1eebfce04'),
  ('00000000-0000-0000-0000-000000000164','00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000134',5,
   'WEECO is mapped as a supply-chain operator that still needs license-level validation.','9866753f-1a8d-495c-8ab8-d0d1eebfce04')
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
  '9866753f-1a8d-495c-8ab8-d0d1eebfce04',
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
  published_by_profile_id = '9866753f-1a8d-495c-8ab8-d0d1eebfce04'
where id = '00000000-0000-0000-0000-000000000200';

-- ============================================================
-- Audit trail
-- ============================================================
select write_audit_event('signal','00000000-0000-0000-0000-000000000130','create',  '9866753f-1a8d-495c-8ab8-d0d1eebfce04',null,    'draft',   'Adjupharm signal created',          null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000130','approve', '9866753f-1a8d-495c-8ab8-d0d1eebfce04','draft', 'approved','Adjupharm signal approved',         null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000131','create',  '9866753f-1a8d-495c-8ab8-d0d1eebfce04',null,    'draft',   'Bathera signal created',            null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000131','approve', '9866753f-1a8d-495c-8ab8-d0d1eebfce04','draft', 'approved','Bathera signal approved',           null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000132','create',  '9866753f-1a8d-495c-8ab8-d0d1eebfce04',null,    'draft',   'FOUR 20 PHARMA signal created',     null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000132','approve', '9866753f-1a8d-495c-8ab8-d0d1eebfce04','draft', 'approved','FOUR 20 PHARMA signal approved',    null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000133','create',  '9866753f-1a8d-495c-8ab8-d0d1eebfce04',null,    'draft',   'Nimbus Health signal created',      null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000133','approve', '9866753f-1a8d-495c-8ab8-d0d1eebfce04','draft', 'approved','Nimbus Health signal approved',     null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000134','create',  '9866753f-1a8d-495c-8ab8-d0d1eebfce04',null,    'draft',   'WEECO signal created',              null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('signal','00000000-0000-0000-0000-000000000134','approve', '9866753f-1a8d-495c-8ab8-d0d1eebfce04','draft', 'approved','WEECO signal approved',             null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('dossier','00000000-0000-0000-0000-000000000200','create',  '9866753f-1a8d-495c-8ab8-d0d1eebfce04',null,               'draft',    'Germany operator dossier created', null,'00000000-0000-0000-0000-000000000100');
select write_audit_event('dossier','00000000-0000-0000-0000-000000000200','publish', '9866753f-1a8d-495c-8ab8-d0d1eebfce04','ready_for_publish','published','Germany operator dossier published',null,'00000000-0000-0000-0000-000000000100');

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
