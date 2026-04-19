-- Workspace isolation v2 hardening
-- Repo note: this repo does not yet contain 001 or 002 migrations.
-- This file targets the canonical Harbourview table contracts assumed by the prior implementation packs:
--   workspace_memberships, contacts, countries, opportunities, tasks, evidence, audit_logs
-- Reconcile names again once the base schema lands.

-- Apply after 002_workspace_isolation.sql

begin;

-- 1. Harden membership table semantics
alter table workspace_memberships
  add constraint workspace_memberships_workspace_user_unique
  unique (workspace_id, user_id);

alter table workspace_memberships
  add constraint workspace_memberships_single_default_per_user
  exclude using gist (
    user_id with =,
    (case when is_default then true else null end) with =
  );

create or replace function app_private.prevent_last_owner_disable()
returns trigger
language plpgsql
as $$
declare
  active_owner_count integer;
begin
  if tg_op = 'update'
     and old.workspace_role = 'owner'
     and old.membership_status = 'active'
     and new.membership_status <> 'active' then

    select count(*) into active_owner_count
    from workspace_memberships wm
    where wm.workspace_id = old.workspace_id
      and wm.workspace_role = 'owner'
      and wm.membership_status = 'active'
      and wm.id <> old.id;

    if active_owner_count = 0 then
      raise exception 'cannot disable the last active owner in a workspace';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_last_owner_disable on workspace_memberships;
create trigger trg_prevent_last_owner_disable
before update on workspace_memberships
for each row
execute function app_private.prevent_last_owner_disable();

-- 2. Enforce same-workspace foreign key semantics where Postgres cannot infer through composite FKs easily
create or replace function app_private.assert_same_workspace_task_opportunity()
returns trigger
language plpgsql
as $$
declare
  parent_workspace_id uuid;
begin
  if new.opportunity_id is null then
    return new;
  end if;

  select o.workspace_id
    into parent_workspace_id
  from opportunities o
  where o.id = new.opportunity_id;

  if parent_workspace_id is null then
    raise exception 'referenced opportunity does not exist';
  end if;

  if parent_workspace_id <> new.workspace_id then
    raise exception 'cross-workspace task/opportunity link is not allowed';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_assert_same_workspace_task_opportunity on tasks;
create trigger trg_assert_same_workspace_task_opportunity
before insert or update on tasks
for each row
execute function app_private.assert_same_workspace_task_opportunity();

-- 3. Admin-only audit log access
alter table audit_logs enable row level security;

drop policy if exists audit_logs_select_same_workspace on audit_logs;
create policy audit_logs_select_same_workspace
on audit_logs
for select
using (
  app_private.current_workspace_id() = workspace_id
  and exists (
    select 1
    from workspace_memberships wm
    where wm.workspace_id = audit_logs.workspace_id
      and wm.user_id = app_private.current_user_id()
      and wm.membership_status = 'active'
      and wm.workspace_role in ('owner', 'admin')
  )
);

drop policy if exists audit_logs_insert_same_workspace on audit_logs;
create policy audit_logs_insert_same_workspace
on audit_logs
for insert
with check (
  workspace_id = app_private.current_workspace_id()
);

-- 4. Stronger workspace-scoped select/insert/update/delete policies for core tenant tables

-- Contacts
drop policy if exists contacts_select_same_workspace on contacts;
create policy contacts_select_same_workspace
on contacts
for select
using (
  workspace_id = app_private.current_workspace_id()
  and exists (
    select 1 from workspace_memberships wm
    where wm.workspace_id = contacts.workspace_id
      and wm.user_id = app_private.current_user_id()
      and wm.membership_status = 'active'
  )
);

drop policy if exists contacts_insert_same_workspace on contacts;
create policy contacts_insert_same_workspace
on contacts
for insert
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists contacts_update_same_workspace on contacts;
create policy contacts_update_same_workspace
on contacts
for update
using (
  workspace_id = app_private.current_workspace_id()
)
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists contacts_delete_same_workspace on contacts;
create policy contacts_delete_same_workspace
on contacts
for delete
using (
  workspace_id = app_private.current_workspace_id()
);

-- Countries
drop policy if exists countries_select_same_workspace on countries;
create policy countries_select_same_workspace
on countries
for select
using (
  workspace_id = app_private.current_workspace_id()
  and exists (
    select 1 from workspace_memberships wm
    where wm.workspace_id = countries.workspace_id
      and wm.user_id = app_private.current_user_id()
      and wm.membership_status = 'active'
  )
);

drop policy if exists countries_insert_same_workspace on countries;
create policy countries_insert_same_workspace
on countries
for insert
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists countries_update_same_workspace on countries;
create policy countries_update_same_workspace
on countries
for update
using (
  workspace_id = app_private.current_workspace_id()
)
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists countries_delete_same_workspace on countries;
create policy countries_delete_same_workspace
on countries
for delete
using (
  workspace_id = app_private.current_workspace_id()
);

-- Opportunities
drop policy if exists opportunities_select_same_workspace on opportunities;
create policy opportunities_select_same_workspace
on opportunities
for select
using (
  workspace_id = app_private.current_workspace_id()
  and exists (
    select 1 from workspace_memberships wm
    where wm.workspace_id = opportunities.workspace_id
      and wm.user_id = app_private.current_user_id()
      and wm.membership_status = 'active'
  )
);

drop policy if exists opportunities_insert_same_workspace on opportunities;
create policy opportunities_insert_same_workspace
on opportunities
for insert
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists opportunities_update_same_workspace on opportunities;
create policy opportunities_update_same_workspace
on opportunities
for update
using (
  workspace_id = app_private.current_workspace_id()
)
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists opportunities_delete_same_workspace on opportunities;
create policy opportunities_delete_same_workspace
on opportunities
for delete
using (
  workspace_id = app_private.current_workspace_id()
);

-- Tasks
drop policy if exists tasks_select_same_workspace on tasks;
create policy tasks_select_same_workspace
on tasks
for select
using (
  workspace_id = app_private.current_workspace_id()
  and exists (
    select 1 from workspace_memberships wm
    where wm.workspace_id = tasks.workspace_id
      and wm.user_id = app_private.current_user_id()
      and wm.membership_status = 'active'
  )
);

drop policy if exists tasks_insert_same_workspace on tasks;
create policy tasks_insert_same_workspace
on tasks
for insert
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists tasks_update_same_workspace on tasks;
create policy tasks_update_same_workspace
on tasks
for update
using (
  workspace_id = app_private.current_workspace_id()
)
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists tasks_delete_same_workspace on tasks;
create policy tasks_delete_same_workspace
on tasks
for delete
using (
  workspace_id = app_private.current_workspace_id()
);

-- Evidence
drop policy if exists evidence_select_same_workspace on evidence;
create policy evidence_select_same_workspace
on evidence
for select
using (
  workspace_id = app_private.current_workspace_id()
  and exists (
    select 1 from workspace_memberships wm
    where wm.workspace_id = evidence.workspace_id
      and wm.user_id = app_private.current_user_id()
      and wm.membership_status = 'active'
  )
);

drop policy if exists evidence_insert_same_workspace on evidence;
create policy evidence_insert_same_workspace
on evidence
for insert
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists evidence_update_same_workspace on evidence;
create policy evidence_update_same_workspace
on evidence
for update
using (
  workspace_id = app_private.current_workspace_id()
)
with check (
  workspace_id = app_private.current_workspace_id()
);

drop policy if exists evidence_delete_same_workspace on evidence;
create policy evidence_delete_same_workspace
on evidence
for delete
using (
  workspace_id = app_private.current_workspace_id()
);

-- 5. Support RPC for explicit audited membership lookup
create or replace function app_public.rpc_list_my_workspaces()
returns table (
  membership_id uuid,
  workspace_id uuid,
  workspace_name text,
  workspace_role text,
  membership_status text,
  is_default boolean
)
language sql
security definer
set search_path = public, app_public, app_private
as $$
  select
    wm.id as membership_id,
    wm.workspace_id,
    w.name as workspace_name,
    wm.workspace_role,
    wm.membership_status,
    wm.is_default
  from workspace_memberships wm
  join workspaces w on w.id = wm.workspace_id
  where wm.user_id = app_private.current_user_id()
    and wm.membership_status in ('active', 'invited')
  order by wm.is_default desc, w.name asc;
$$;

revoke all on function app_public.rpc_list_my_workspaces() from public;
grant execute on function app_public.rpc_list_my_workspaces() to authenticated;

commit;
