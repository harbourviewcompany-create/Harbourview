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
