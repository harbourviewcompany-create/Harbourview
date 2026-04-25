# Task Index

## HV-001
Title: Shared AI-agent operating layer
Status: In progress
Priority: High
Owner: ChatGPT
Branch: agent/chatgpt/HV-001-agent-operating-layer
Files/areas:
- agent-workspace/**
- .github/**
- package.json test scripts
Acceptance criteria:
- [ ] Agent workspace files exist.
- [ ] GitHub pull request template exists.
- [ ] GitHub issue template exists.
- [ ] CI verification workflow exists or current Security CI covers the gate.
- [ ] Verification commands are documented.
- [ ] Handoff files are updated.
- [ ] PR is mergeable.
- [ ] Required CI checks pass.
PR: #1

## HV-002
Title: Production security and RLS hardening
Status: Backlog
Priority: Critical
Owner: unassigned
Branch: pending
Files/areas:
- supabase/**
- lib/security/**
- app/api/**
- supabase/functions/**
Acceptance criteria:
- [ ] Live schema or migration source reviewed.
- [ ] RLS and workspace isolation verified.
- [ ] Tokenized feed access reviewed.
- [ ] Service-side key usage reviewed.
- [ ] Tests added or repaired.
- [ ] Verification commands pass.
PR: pending
