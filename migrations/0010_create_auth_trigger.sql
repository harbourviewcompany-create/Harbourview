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
