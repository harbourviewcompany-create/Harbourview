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
