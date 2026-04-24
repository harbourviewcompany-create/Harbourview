# Security Policy

## Current security status

This project must be treated as not production-ready until the production Supabase secret has been rotated, the live schema/RLS policies have been exported and reviewed, and CI passes on a protected branch.

## Secret handling rules

- Never commit `.env`, `.env.local`, `.env.production` or deployment secret dumps.
- Never place service-role keys in `NEXT_PUBLIC_*` variables.
- `SUPABASE_SERVICE_ROLE_KEY` is server-only and may only be used in route handlers, server-only helpers, background jobs or controlled administrative scripts.
- Public feed tokens must never be stored raw. Store only SHA-256 token hashes in `public_feed_tokens.token_hash`.
- CI runs Gitleaks and must block on detected secrets.

## Required immediate action after the exposed Supabase secret

1. Open Supabase Dashboard.
2. Select the Harbourview project.
3. Go to Project Settings > API.
4. Rotate/regenerate the service-role secret.
5. Update deployment secrets in Vercel or the active hosting provider.
6. Update local `.env.local` only on trusted machines.
7. Remove the old secret from any notes, logs, chat exports, shell history and local files.
8. Redeploy the application.
9. Run the admin health check as an authenticated admin.
10. Review Supabase logs for use of the old service-role key after rotation.

## Local secret scanning

Run before pushing:

```bash
gitleaks detect --source . --redact --verbose
```

## Reporting

Report suspected credential exposure, RLS bypass, public feed leakage or unauthorized workspace access as a critical incident and follow `INCIDENT_RESPONSE.md`.
