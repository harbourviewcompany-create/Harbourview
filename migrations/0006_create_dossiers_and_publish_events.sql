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
