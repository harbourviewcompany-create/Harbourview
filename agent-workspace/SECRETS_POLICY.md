# Credential Policy

## Rules
- Never commit real credentials.
- Never paste private keys, API tokens, database passwords or service keys into handoff files.
- Use `.env.example` for variable names only.
- Treat any accidentally published credential as no longer trustworthy.
- Rotate any accidentally published credential through the provider dashboard or CLI.
- Add scanning to CI where practical.
- Do not use service-level credentials in client code.
- Do not log tokens, session data or private payloads.
- Do not print full environment variable values in CI logs.

## Environment files
Allowed:
- `.env.example`
- documented variable names
- local `.env.local` ignored by git

Not allowed:
- real `.env` values in git
- screenshots containing private credentials
- private credential values in issues, PRs, handoff logs or comments

## Required response to exposure
If a private credential appears in code, logs, issues, PRs or chat:

1. Stop using the value.
2. Remove it from repo content.
3. Rotate it in the provider dashboard.
4. Check git history and public logs.
5. Record only the remediation status, not the value.
