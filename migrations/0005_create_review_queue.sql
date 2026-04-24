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
