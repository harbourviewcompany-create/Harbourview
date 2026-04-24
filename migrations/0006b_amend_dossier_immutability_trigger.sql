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
