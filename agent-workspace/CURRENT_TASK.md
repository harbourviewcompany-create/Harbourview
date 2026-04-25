# Current Task

## Task ID
HV-001

## Objective
Implement the shared AI-agent operating layer and GitHub infrastructure required for ChatGPT, Claude and future agents to work on the same software project safely.

## Scope
- Add agent workspace files.
- Add task tracking and lock rules.
- Add definition of done.
- Add migration, credential, conflict and rollback policies.
- Add verification commands.
- Add GitHub pull request and issue templates.
- Add GitHub Actions verification workflow if missing.

## Out of scope
- Feature development.
- Database schema changes.
- Direct production deployment.
- Merging to `main` without review.

## Status
In progress

## Branch
agent/chatgpt/HV-001-agent-operating-layer

## Files/areas reserved
- agent-workspace/**
- .github/**
- package.json test scripts

## Acceptance criteria
- [ ] Agent workspace files exist.
- [ ] PR template exists.
- [ ] Issue template exists.
- [ ] CI verification workflow exists or current Security CI covers the gate.
- [ ] Verification commands are documented.
- [ ] Handoff log updated.
- [ ] Pull request remains mergeable.
- [ ] Required CI checks pass.

## Last known failure
GitHub marked the earlier PR head unmergeable because the branch was behind current `main`. The branch was reset onto current `main` and HV-001 changes are being reapplied.
