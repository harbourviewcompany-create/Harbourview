-- Harbourbase Core Database v1
-- Supabase/Postgres operating-memory layer with workspace isolation, lifecycle states, audit trail and RLS.

create extension if not exists pgcrypto;
create extension if not exists vector;

do $$ begin
  create type public.workspace_role as enum ('viewer','operator','admin','agent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.lifecycle_status as enum ('draft','active','archived','superseded','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.review_status as enum ('pending','accepted','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.confidence_level as enum ('untrusted','suggested','source_backed','operator_verified');
exception when duplicate_object then null; end $$;

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  status lifecycle_status not null default 'active',
  archived_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  role workspace_role not null,
  status lifecycle_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,user_id)
);

create table if not exists public.memory_nodes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  title text not null,
  node_type text not null,
  body text,
  tags text[] not null default '{}',
  confidence confidence_level not null default 'untrusted',
  source_backed boolean not null default false,
  status lifecycle_status not null default 'draft',
  supersedes_node_id uuid references public.memory_nodes(id),
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memory_edge_types (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  key text not null,
  label text not null,
  description text,
  status lifecycle_status not null default 'active',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,key)
);

create table if not exists public.memory_edges (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  from_node_id uuid not null references public.memory_nodes(id) on delete restrict,
  to_node_id uuid not null references public.memory_nodes(id) on delete restrict,
  edge_type_id uuid not null references public.memory_edge_types(id) on delete restrict,
  description text,
  confidence confidence_level not null default 'untrusted',
  source_backed boolean not null default false,
  status lifecycle_status not null default 'draft',
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (from_node_id <> to_node_id)
);

create table if not exists public.file_registry (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  storage_bucket text,
  storage_path text,
  external_url text,
  file_name text not null,
  mime_type text,
  byte_size bigint,
  sha256 text,
  source_system text not null default 'manual',
  status lifecycle_status not null default 'active',
  created_by uuid references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (storage_path is not null or external_url is not null)
);

create table if not exists public.memory_evidence (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  node_id uuid references public.memory_nodes(id) on delete restrict,
  edge_id uuid references public.memory_edges(id) on delete restrict,
  file_id uuid references public.file_registry(id) on delete restrict,
  source_url text,
  quote text,
  summary text,
  review_status review_status not null default 'pending',
  status lifecycle_status not null default 'active',
  created_by uuid references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((node_id is not null)::int + (edge_id is not null)::int = 1),
  check (file_id is not null or source_url is not null or quote is not null or summary is not null)
);

create table if not exists public.ai_memory_suggestions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  suggested_node jsonb,
  suggested_edge jsonb,
  rationale text,
  source_trace jsonb not null default '[]'::jsonb,
  review_status review_status not null default 'pending',
  created_memory_node_id uuid references public.memory_nodes(id),
  created_memory_edge_id uuid references public.memory_edges(id),
  created_by uuid references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  status lifecycle_status not null default 'active',
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (suggested_node is not null or suggested_edge is not null)
);

create table if not exists public.prompt_registry (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  name text not null,
  purpose text not null,
  prompt_body text not null,
  version integer not null default 1,
  status lifecycle_status not null default 'active',
  created_by uuid references auth.users(id),
  supersedes_prompt_id uuid references public.prompt_registry(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,name,version)
);

create table if not exists public.ai_handoff_records (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  from_agent text not null,
  to_agent text,
  task_context text not null,
  payload jsonb not null default '{}'::jsonb,
  status lifecycle_status not null default 'active',
  created_by uuid references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.decision_log (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  title text not null,
  decision text not null,
  rationale text,
  status lifecycle_status not null default 'active',
  decided_by uuid references auth.users(id),
  decided_at timestamptz not null default now(),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.work_tasks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  title text not null,
  description text,
  task_status text not null default 'todo',
  priority text not null default 'normal',
  assigned_to uuid references auth.users(id),
  due_at timestamptz,
  status lifecycle_status not null default 'active',
  created_by uuid references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  actor_user_id uuid references auth.users(id),
  action text not null,
  table_name text not null,
  record_id uuid,
  old_record jsonb,
  new_record jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.current_workspace_role(target_workspace_id uuid)
returns workspace_role
language sql
security definer
set search_path = public
stable
as $$
  select wm.role
  from public.workspace_members wm
  where wm.workspace_id = target_workspace_id
    and wm.user_id = auth.uid()
    and wm.status = 'active'
  limit 1
$$;

create or replace function public.can_read_workspace(target_workspace_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select public.current_workspace_role(target_workspace_id) is not null
$$;

create or replace function public.can_write_workspace(target_workspace_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select public.current_workspace_role(target_workspace_id) in ('operator','admin')
$$;

create or replace function public.can_admin_workspace(target_workspace_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select public.current_workspace_role(target_workspace_id) = 'admin'
$$;

create or replace function public.can_agent_suggest(target_workspace_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select public.current_workspace_role(target_workspace_id) in ('agent','operator','admin')
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create or replace function public.prevent_hard_delete()
returns trigger language plpgsql as $$
begin
  raise exception 'Hard delete is disabled. Archive or supersede this record instead.';
end $$;

create or replace function public.enforce_source_backed_evidence()
returns trigger language plpgsql as $$
begin
  if (new.confidence = 'source_backed' or new.source_backed is true) then
    if tg_table_name = 'memory_nodes' and not exists (
      select 1 from public.memory_evidence e
      where e.node_id = new.id and e.review_status = 'accepted' and e.status = 'active'
    ) then
      raise exception 'Source-backed memory requires accepted evidence.';
    end if;
    if tg_table_name = 'memory_edges' and not exists (
      select 1 from public.memory_evidence e
      where e.edge_id = new.id and e.review_status = 'accepted' and e.status = 'active'
    ) then
      raise exception 'Source-backed memory requires accepted evidence.';
    end if;
  end if;
  return new;
end $$;

create or replace function public.audit_row_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  record_workspace uuid;
  action_name text;
begin
  record_workspace := coalesce((to_jsonb(new)->>'workspace_id')::uuid, (to_jsonb(old)->>'workspace_id')::uuid);
  action_name := lower(tg_op);
  if tg_op = 'UPDATE' and coalesce(to_jsonb(new)->>'status','') = 'archived' and coalesce(to_jsonb(old)->>'status','') <> 'archived' then
    action_name := 'archive';
  end if;
  insert into public.audit_events(workspace_id, actor_user_id, action, table_name, record_id, old_record, new_record)
  values (
    record_workspace,
    auth.uid(),
    action_name,
    tg_table_name,
    coalesce(new.id, old.id),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end
  );
  return coalesce(new, old);
end $$;

create or replace function public.approve_ai_memory_suggestion(suggestion_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.ai_memory_suggestions%rowtype;
  new_node_id uuid;
begin
  select * into s from public.ai_memory_suggestions where id = suggestion_id for update;
  if not found then raise exception 'Suggestion not found'; end if;
  if not public.can_write_workspace(s.workspace_id) then raise exception 'Insufficient permission'; end if;
  if s.review_status <> 'pending' then raise exception 'Suggestion already reviewed'; end if;
  if s.suggested_node is null then raise exception 'Only node suggestion approval is supported in v1 service function'; end if;

  insert into public.memory_nodes(workspace_id,title,node_type,body,tags,confidence,source_backed,status,created_by,updated_by)
  values (
    s.workspace_id,
    coalesce(s.suggested_node->>'title','Untitled memory'),
    coalesce(s.suggested_node->>'node_type','general'),
    s.suggested_node->>'body',
    coalesce(array(select jsonb_array_elements_text(s.suggested_node->'tags')), '{}'),
    'suggested',
    false,
    'draft',
    auth.uid(),
    auth.uid()
  )
  returning id into new_node_id;

  update public.ai_memory_suggestions
  set review_status='accepted',
      reviewed_by=auth.uid(),
      reviewed_at=now(),
      created_memory_node_id=new_node_id,
      updated_at=now()
  where id=suggestion_id;

  return new_node_id;
end $$;

create index if not exists idx_workspace_members_user on public.workspace_members(user_id, workspace_id);
create index if not exists idx_memory_nodes_workspace on public.memory_nodes(workspace_id, status);
create index if not exists idx_memory_nodes_search on public.memory_nodes using gin (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(body,'')));
create index if not exists idx_memory_edges_workspace on public.memory_edges(workspace_id, status);
create index if not exists idx_memory_evidence_node on public.memory_evidence(node_id, review_status);
create index if not exists idx_memory_evidence_edge on public.memory_evidence(edge_id, review_status);
create index if not exists idx_audit_workspace on public.audit_events(workspace_id, created_at desc);

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.memory_nodes enable row level security;
alter table public.memory_edges enable row level security;
alter table public.memory_edge_types enable row level security;
alter table public.memory_evidence enable row level security;
alter table public.file_registry enable row level security;
alter table public.ai_memory_suggestions enable row level security;
alter table public.prompt_registry enable row level security;
alter table public.ai_handoff_records enable row level security;
alter table public.decision_log enable row level security;
alter table public.work_tasks enable row level security;
alter table public.audit_events enable row level security;

-- RLS policies
create policy workspaces_select on public.workspaces for select using (public.can_read_workspace(id));
create policy workspaces_insert on public.workspaces for insert with check (created_by = auth.uid());
create policy workspaces_update on public.workspaces for update using (public.can_admin_workspace(id)) with check (public.can_admin_workspace(id));
create policy workspace_members_select on public.workspace_members for select using (public.can_read_workspace(workspace_id));
create policy workspace_members_write on public.workspace_members for all using (public.can_admin_workspace(workspace_id)) with check (public.can_admin_workspace(workspace_id));
create policy memory_nodes_select on public.memory_nodes for select using (public.can_read_workspace(workspace_id));
create policy memory_nodes_insert on public.memory_nodes for insert with check (public.can_write_workspace(workspace_id));
create policy memory_nodes_update on public.memory_nodes for update using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy memory_edges_select on public.memory_edges for select using (public.can_read_workspace(workspace_id));
create policy memory_edges_insert on public.memory_edges for insert with check (public.can_write_workspace(workspace_id));
create policy memory_edges_update on public.memory_edges for update using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy memory_edge_types_select on public.memory_edge_types for select using (public.can_read_workspace(workspace_id));
create policy memory_edge_types_write on public.memory_edge_types for all using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy memory_evidence_select on public.memory_evidence for select using (public.can_read_workspace(workspace_id));
create policy memory_evidence_write on public.memory_evidence for all using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy file_registry_select on public.file_registry for select using (public.can_read_workspace(workspace_id));
create policy file_registry_write on public.file_registry for all using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy ai_memory_suggestions_select on public.ai_memory_suggestions for select using (public.can_read_workspace(workspace_id));
create policy ai_memory_suggestions_insert on public.ai_memory_suggestions for insert with check (public.can_agent_suggest(workspace_id));
create policy ai_memory_suggestions_update on public.ai_memory_suggestions for update using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy prompt_registry_select on public.prompt_registry for select using (public.can_read_workspace(workspace_id));
create policy prompt_registry_write on public.prompt_registry for all using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy ai_handoff_records_select on public.ai_handoff_records for select using (public.can_read_workspace(workspace_id));
create policy ai_handoff_records_insert on public.ai_handoff_records for insert with check (public.can_agent_suggest(workspace_id));
create policy ai_handoff_records_update on public.ai_handoff_records for update using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy decision_log_select on public.decision_log for select using (public.can_read_workspace(workspace_id));
create policy decision_log_write on public.decision_log for all using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy work_tasks_select on public.work_tasks for select using (public.can_read_workspace(workspace_id));
create policy work_tasks_write on public.work_tasks for all using (public.can_write_workspace(workspace_id)) with check (public.can_write_workspace(workspace_id));
create policy audit_events_select on public.audit_events for select using (public.can_read_workspace(workspace_id));
create policy audit_events_insert on public.audit_events for insert with check (true);

do $$
declare t text;
begin
  foreach t in array array[
    'workspaces','workspace_members','memory_nodes','memory_edges','memory_edge_types',
    'memory_evidence','file_registry','ai_memory_suggestions','prompt_registry',
    'ai_handoff_records','decision_log','work_tasks'
  ] loop
    execute format('create trigger trg_%I_updated_at before update on public.%I for each row execute function public.touch_updated_at()', t, t);
    execute format('create trigger trg_%I_no_delete before delete on public.%I for each row execute function public.prevent_hard_delete()', t, t);
    execute format('create trigger trg_%I_audit after insert or update on public.%I for each row execute function public.audit_row_change()', t, t);
  end loop;
end $$;

create trigger trg_memory_nodes_source_evidence before insert or update on public.memory_nodes
for each row execute function public.enforce_source_backed_evidence();

create trigger trg_memory_edges_source_evidence before insert or update on public.memory_edges
for each row execute function public.enforce_source_backed_evidence();
