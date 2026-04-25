# Verification Commands

## Standard local verification
Run from repo root.

```bash
npm ci
npm run typecheck
npm test
npm run build
```

## Live Supabase acceptance tests
Only run when the live Supabase test environment is configured.

```bash
npm run test:acceptance
```

Required environment values:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `TEST_ADMIN_EMAIL`
- `TEST_ADMIN_PASSWORD`
- `TEST_ANALYST_EMAIL`
- `TEST_ANALYST_PASSWORD`
- `APP_URL`

## Development server
```bash
npm run dev
```

## Windows PowerShell local verification
```powershell
npm ci
npm run typecheck
npm test
npm run build
```

## CI verification
GitHub Actions should run install, typecheck, default tests, build, scanning and agent-workspace checks on pull requests to `main`.

## If verification cannot run
Document the reason in:

- `agent-workspace/LAST_RUN.md`
- `agent-workspace/HANDOFF_LOG.md`
- PR body

Do not claim the task is complete unless the limitation is explicit.
