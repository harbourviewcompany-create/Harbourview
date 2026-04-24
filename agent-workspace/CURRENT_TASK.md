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
- Add GitHub Actions verification workflow.

## Out of scope
- Feature development.
- Database schema changes.
- Direct production deployment.
- Merging to `main` without review.
- Dashboard-only branch protection changes that cannot be configured from repo files.

## Status
In progress

## Branch
agent/chatgpt/HV-001-agent-operating-layer

## Files/areas reserved
- agent-workspace/**
- .github/**

## Acceptance criteria
- [ ] Agent workspace files exist.
- [ ] PR template exists.
- [ ] Issue template exists.
- [ ] CI verification workflow exists.
- [ ] Verification commands are documented.
- [ ] Handoff log updated.
- [ ] Pull request opened for human review.

## Last known failure
Command: none in this task yet
Result: not run
Relevant error: not applicable
