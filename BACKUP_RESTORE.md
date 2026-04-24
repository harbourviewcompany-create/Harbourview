# Backup and Restore

## Backup requirements

- Supabase automatic daily backups must be enabled for production.
- A manual backup must be taken before every production schema migration.
- A restore drill must be performed at least monthly against a non-production project.

## Pre-migration backup

1. Open Supabase Dashboard.
2. Select the production project.
3. Confirm latest automatic backup completed successfully.
4. Create a manual backup if the plan supports it.
5. Export schema and policies:

```bash
supabase db dump --schema public --file backups/$(date +%Y%m%d)-public.sql
psql "$DATABASE_URL" -f scripts/export-rls-policies.sql > backups/$(date +%Y%m%d)-rls-policies.txt
```

## Restore drill

1. Create or select a staging Supabase project.
2. Restore the latest production backup into staging.
3. Apply pending migrations.
4. Run app against staging env vars.
5. Run:

```bash
npm ci
npm run typecheck
npm run lint
npm test
npm run build
```

6. Validate admin health endpoint.
7. Validate that a client user cannot access another workspace.
8. Validate public feed tokens: valid, invalid, expired and revoked.

## Emergency restore

1. Freeze writes if active corruption or unauthorized writes are suspected.
2. Snapshot current production state for forensic review.
3. Restore from the last known-good backup.
4. Rotate service-role key and any affected feed tokens.
5. Redeploy app with verified env vars.
6. Run health check and tenant-isolation tests.
7. Record incident notes.
