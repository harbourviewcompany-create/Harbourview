# Project State

## Project
Name: Harbourview
Repository: harbourviewcompany-create/Harbourview
Primary stack: Next.js App Router, TypeScript, React, Tailwind, Supabase Auth, Supabase Postgres, Supabase Edge Functions, GitHub Actions
Operating system target: Windows 10 local operator workflow plus Vercel/Supabase deployment path

## Product intent
Harbourview is a commercial-intelligence and market-access platform. The system should support controlled publishing, tokenized feed access, admin workflows, evidence/provenance, marketplace/intake workflows, auditability and strict tenant/workspace isolation.

## Current status
Runnable locally: unverified in this baseline
Build passing: unverified in this baseline
Tests passing: unverified in this baseline
Deployment ready: no, production readiness requires verified CI, credential hygiene, RLS review and deployment checks

## Current priority
HV-001: Establish the shared AI-agent operating layer so ChatGPT, Claude and future agents work from the same repo state, task system, verification rules and handoff process.

## Source of truth rules
- GitHub repo is the source of truth for code.
- `agent-workspace/` is the source of truth for agent state, task continuity and handoff.
- GitHub Issues or `agent-workspace/TASK_INDEX.md` are the source of truth for work queue.
- Branches and pull requests are the source of truth for proposed changes.
- GitHub Actions and local verification commands are the source of truth for whether work passes.

## Verified facts
- Default branch is `main`.
- `package.json` includes scripts for `dev`, `build`, `start`, `lint`, `test`, `test:watch` and `typecheck`.
- The repo currently has GitHub connector write access for this agent.

## Unverified assumptions
- Supabase schema and RLS policies are complete and safe.
- All required environment variables are documented.
- Existing tests fully cover security-sensitive flows.
- Local Windows setup is frictionless.

## Known blockers
- Production readiness cannot be claimed until CI passes and security/RLS review is complete.
- Branch protection and required checks must be enabled in GitHub settings after the workflow exists.
