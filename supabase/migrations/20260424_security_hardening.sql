-- Harbourview production security hardening migration
-- Apply only after reviewing against the current production schema.
-- This migration intentionally fails loudly if expected tables are missing.

begin;

create extension if not exists pgcrypto;

-- Public-feed tokens use hashed tokens only. Raw tokens must never be stored.
create table if not exists public.public_feed_tokens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  publish_event_id uuid references public.publish_events(id) on delete restrict,
  token_hash text not null unique,
  status text not null default 'active' check (status in ('active', 'revoked', 'expired')),
  snapshot jsonb not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  revoked_by_profile_id uuid references public.profiles(id) on delete set null,
  created_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint public_feed_tokens_hash_shape check (token_hash ~ '^[a-f0-9]{64}$'),
  constraint public_feed_tokens_revoked_consistency check (
    (status = 'revoked' and revoked_at is not null) or
    (status <> 'revoked')
  )
);

create table if not exists public.public_feed_token_access_events (
  id uuid primary key default gen_random_uuid(),
  public_feed_token_id uuid not null references public.public_feed_tokens(id) on delete cascade,
  accessed_at timestamptz not null default now(),
  ip_hash text,
  user_agent text
);

create index if not exists public_feed_tokens_workspace_idx on public.public_feed_tokens(workspace_id);
create index if not exists public_feed_tokens_status_expiry_idx on public.public_feed_tokens(status, expires_at);
create index if not exists public_feed_token_access_events_token_idx on public.public_feed_token_access_events(public_feed_token_id, accessed_at desc);

-- Generic updated_at trigger.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_public_feed_tokens_updated_at on public.public_feed_tokens;
create trigger set_public_feed_tokens_updated_at
before update on public.public_feed_tokens
for each row execute function public.set_updated_at();

-- Workspace membership and role helpers.
-- Assumes workspace_memberships has workspace_id, profile_id and role/status columns.
-- If your current schema differs, update this helper before applying.
create or replace function public.current_profile_id()
returns uuid
language sql
stable
as $$
  select auth.uid();
$$;

create or replace function public.current_platform_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.platform_role
  from public.profiles p
  where p.id = auth.uid();
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_platform_role() = 'admin', false);
$$;

create or replace function public.is_workspace_member(target_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_memberships wm
    where wm.workspace_id = target_workspace_id
      and wm.profile_id = auth.uid()
      and coalesce(wm.status, 'active') = 'active'
  ) or public.is_platform_admin();
$$;

create or replace function public.is_workspace_operator(target_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.workspace_memberships wm
    where wm.workspace_id = target_workspace_id
      and wm.profile_id = auth.uid()
      and coalesce(wm.status, 'active') = 'active'
      and coalesce(wm.role, '') in ('owner', 'admin', 'analyst')
  ) or public.is_platform_admin();
$$;

-- Enable and force RLS on sensitive known tables.
do $$
declare
  table_name text;
  tables text[] := array[
    'profiles',
    'workspaces',
    'workspace_memberships',
    'signals',
    'signal_evidence',
    'sources',
    'source_documents',
    'review_queue_items',
    'publish_events',
    'public_feed_tokens',
    'public_feed_token_access_events'
  ];
begin
  foreach table_name in array tables loop
    if to_regclass('public.' || table_name) is null then
      raise exception 'Expected table public.% is missing. Review schema before applying hardening migration.', table_name;
    end if;
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
  end loop;
end $$;

-- Profiles: users can read self; admins can read all. Users cannot self-promote.
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles
for select to authenticated
using (id = auth.uid() or public.is_platform_admin());

drop policy if exists profiles_update_self_limited on public.profiles;
create policy profiles_update_self_limited on public.profiles
for update to authenticated
using (id = auth.uid() or public.is_platform_admin())
with check (
  public.is_platform_admin() or (
    id = auth.uid()
    and platform_role = (select platform_role from public.profiles where id = auth.uid())
    and default_workspace_id = (select default_workspace_id from public.profiles where id = auth.uid())
  )
);

-- Workspaces and memberships.
drop policy if exists workspaces_select_member on public.workspaces;
create policy workspaces_select_member on public.workspaces
for select to authenticated
using (public.is_workspace_member(id));

drop policy if exists workspaces_operator_write on public.workspaces;
create policy workspaces_operator_write on public.workspaces
for all to authenticated
using (public.is_workspace_operator(id))
with check (public.is_workspace_operator(id));

drop policy if exists workspace_memberships_select_member_or_admin on public.workspace_memberships;
create policy workspace_memberships_select_member_or_admin on public.workspace_memberships
for select to authenticated
using (profile_id = auth.uid() or public.is_workspace_operator(workspace_id));

drop policy if exists workspace_memberships_operator_write on public.workspace_memberships;
create policy workspace_memberships_operator_write on public.workspace_memberships
for all to authenticated
using (public.is_workspace_operator(workspace_id))
with check (public.is_workspace_operator(workspace_id));

-- Workspace-scoped content. Assumes each table has workspace_id except evidence/documents may join through parent records.
drop policy if exists signals_workspace_select on public.signals;
create policy signals_workspace_select on public.signals
for select to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists signals_workspace_operator_write on public.signals;
create policy signals_workspace_operator_write on public.signals
for all to authenticated
using (public.is_workspace_operator(workspace_id))
with check (public.is_workspace_operator(workspace_id));

drop policy if exists sources_workspace_select on public.sources;
create policy sources_workspace_select on public.sources
for select to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists sources_workspace_operator_write on public.sources;
create policy sources_workspace_operator_write on public.sources
for all to authenticated
using (public.is_workspace_operator(workspace_id))
with check (public.is_workspace_operator(workspace_id));

drop policy if exists source_documents_workspace_select on public.source_documents;
create policy source_documents_workspace_select on public.source_documents
for select to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists source_documents_workspace_operator_write on public.source_documents;
create policy source_documents_workspace_operator_write on public.source_documents
for all to authenticated
using (public.is_workspace_operator(workspace_id))
with check (public.is_workspace_operator(workspace_id));

drop policy if exists review_queue_items_workspace_select on public.review_queue_items;
create policy review_queue_items_workspace_select on public.review_queue_items
for select to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists review_queue_items_workspace_operator_write on public.review_queue_items;
create policy review_queue_items_workspace_operator_write on public.review_queue_items
for all to authenticated
using (public.is_workspace_operator(workspace_id))
with check (public.is_workspace_operator(workspace_id));

drop policy if exists publish_events_workspace_select on public.publish_events;
create policy publish_events_workspace_select on public.publish_events
for select to authenticated
using (public.is_workspace_member(workspace_id));

drop policy if exists publish_events_workspace_operator_insert on public.publish_events;
create policy publish_events_workspace_operator_insert on public.publish_events
for insert to authenticated
with check (public.is_workspace_operator(workspace_id));

-- Publish events are append-only after insert.
drop policy if exists publish_events_no_update on public.publish_events;
create policy publish_events_no_update on public.publish_events
for update to authenticated
using (false)
with check (false);

drop policy if exists publish_events_no_delete on public.publish_events;
create policy publish_events_no_delete on public.publish_events
for delete to authenticated
using (false);

-- Evidence inherits signal workspace access.
drop policy if exists signal_evidence_workspace_select on public.signal_evidence;
create policy signal_evidence_workspace_select on public.signal_evidence
for select to authenticated
using (
  exists (
    select 1 from public.signals s
    where s.id = signal_evidence.signal_id
      and public.is_workspace_member(s.workspace_id)
  )
);

drop policy if exists signal_evidence_workspace_operator_write on public.signal_evidence;
create policy signal_evidence_workspace_operator_write on public.signal_evidence
for all to authenticated
using (
  exists (
    select 1 from public.signals s
    where s.id = signal_evidence.signal_id
      and public.is_workspace_operator(s.workspace_id)
  )
)
with check (
  exists (
    select 1 from public.signals s
    where s.id = signal_evidence.signal_id
      and public.is_workspace_operator(s.workspace_id)
  )
);

-- Public feed token tables are service-role only. No anonymous or authenticated direct access.
drop policy if exists public_feed_tokens_no_direct_access on public.public_feed_tokens;
create policy public_feed_tokens_no_direct_access on public.public_feed_tokens
for all to anon, authenticated
using (false)
with check (false);

drop policy if exists public_feed_token_access_events_no_direct_access on public.public_feed_token_access_events;
create policy public_feed_token_access_events_no_direct_access on public.public_feed_token_access_events
for all to anon, authenticated
using (false)
with check (false);

-- Guard against accidental raw token columns on publish_events.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'publish_events'
      and column_name = 'api_token'
  ) then
    raise notice 'SECURITY WARNING: public.publish_events.api_token exists. Backfill to public_feed_tokens and drop this column in a dedicated migration after clients move to v2 feed tokens.';
  end if;
end $$;

commit;
