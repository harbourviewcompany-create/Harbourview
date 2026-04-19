# Harbourview

Harbourview is the regulated market-access operating system for evidence-backed internal workstreams.

## Current contents

This repository now contains a real runnable application baseline instead of only a placeholder README:

- `apps/web`: Next.js App Router app with Supabase SSR authentication wiring
- root workspace scripts for local development
- secure environment examples with no committed live secrets

## Why this baseline exists

The connected GitHub repository was effectively empty apart from the initial README. The first direct change is to establish a working authenticated operator shell so the API, ingestion, rules engine, workflows, and dossier surfaces can land on top of a real structure.

## Local setup

1. Copy `apps/web/.env.local.example` to `apps/web/.env.local`
2. Fill in your real Supabase values
3. Install dependencies
4. Start the web app

```bash
npm install
npm run dev:web
```

## Required environment variables

```bash
NEXT_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
```

## Notes

- Do not commit real environment values.
- Middleware is included to keep Supabase sessions refreshed.
- This is the clean starting point for the deeper regulated-market backend and workflow layers.
