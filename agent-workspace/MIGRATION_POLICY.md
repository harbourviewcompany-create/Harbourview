# Migration Policy

## Rules
- Never modify a migration that has already been applied to a shared or production database.
- Add a new migration for schema changes.
- Every migration must include rollback notes or a reason rollback is not safe.
- RLS changes must include verification queries, tests or a documented manual verification path.
- Tenant/workspace isolation must be explicitly tested for protected tables.
- Seed data must not contain real credentials, customer records or private operator data.
- Schema changes must update generated types when the project uses generated database types.
- Migrations must be idempotent where practical.
- Destructive migrations require explicit operator approval.

## Required migration handoff
For any database task, update:

- `HANDOFF_LOG.md`
- `OPEN_ISSUES.md`
- `LAST_RUN.md`

Include:

- migration file path
- tables changed
- policies changed
- verification performed
- rollback notes

## RLS review minimum
For each protected table, confirm:

- RLS enabled
- default access is denied unless policy permits
- workspace or tenant boundary is present where relevant
- public access is intentional and documented
- service-level credential usage is server-only
