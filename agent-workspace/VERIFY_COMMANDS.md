# Verification Commands

## Standard local verification
Run from repo root.

```bash
npm ci
npm run typecheck
npm test
npm run build
```

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

## Expected scripts
These scripts are expected in `package.json`:

- `dev`
- `build`
- `start`
- `lint`
- `test`
- `test:watch`
- `typecheck`

## CI verification
GitHub Actions should run install, typecheck, tests, build, secret scanning and agent-workspace enforcement on pull requests to `main`.

## If verification cannot run
Document the reason in:

- `agent-workspace/LAST_RUN.md`
- `agent-workspace/HANDOFF_LOG.md`
- PR body

Do not claim the task is complete unless the limitation is explicit.
