# Project State

## Project
Name: Harbourview
Repository: harbourviewcompany-create/Harbourview
Primary stack: Next.js App Router, TypeScript, React, Tailwind, Supabase Auth, Supabase Postgres, Supabase Edge Functions, GitHub Actions
Operating target: Windows 10 local workflow plus Vercel/Supabase deployment path

## Product intent
Harbourview is a commercial-intelligence and market-access platform. It should support controlled publishing, tokenized feed access, admin workflows, evidence/provenance, marketplace/intake workflows, auditability and strict tenant/workspace isolation.

## Current status
Runnable locally: unverified in this baseline
Build passing: pending CI
Tests passing: pending CI
Deployment ready: no

## Current priority
HV-001: Establish the shared AI-agent operating layer so ChatGPT, Claude and future agents work from the same repo state, task system, verification rules and handoff process.

## Source of truth rules
- GitHub repo is the source of truth for code.
- `agent-workspace/` is the source of truth for agent state, task continuity and handoff.
- Branches and pull requests are the source of truth for proposed changes.
- GitHub Actions and local verification commands are the source of truth for whether work passes.

## Verified facts
- Default branch is `main`.
- The branch was reset onto current `main` on 2026-04-24 to remove divergence.

## Known blockers
- Production readiness cannot be claimed until CI passes and security/RLS review is complete.
- Branch protection and required checks must be enabled in GitHub settings after this PR is merged.
