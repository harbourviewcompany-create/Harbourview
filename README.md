# Harbourview wired Next.js UI pack

This pack converts the standalone Harbourview HTML shell into a real Next.js App Router UI backed by the existing Supabase server actions and adds a dedicated read-model layer plus internal JSON routes.

## What is included

- Real operator pages for overview, sources, signals, review queue, dossiers, audit log and publish preview
- Read-model query layer under `lib/queries/*`
- Internal API routes under `app/api/internal/*`
- Publish preview validator under `lib/publish/validate.ts`
- Tokened client feed route under `app/api/feed/[token]/route.ts`

## Important implementation notes

1. The new signal form requires a real `source_document_id`. This pack does not guess one.
3. The publish preview blocks publication when signals are not approved or do not have human evidence.
4. The internal API routes assume authenticated operator access via middleware.

## Suggested next patch

- review queue status flow normalized for v1: submit creates `pending` and admin approve/reject resolves that same queue item
- signal evidence form uses a real source-document picker instead of free-text UUID entry
- add toast/error surfaces for server action failures
- replace free-text `source_document_id` entry with a searchable document picker


## Latest patch

- Added post-create evidence attachment on the signal detail page.
- Reused the real source-document picker so operators attach evidence against actual source documents rather than free-text IDs.
- Added state-aware gating on the signal detail actions so submit, approve and reject only activate in the correct review state.
