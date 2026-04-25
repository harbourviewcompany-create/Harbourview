# Decisions

## Decision HV-D001: Repo-first agent workflow
Decision: GitHub repository files are the canonical source of truth for code, task state, handoff and proposed changes.
Reason: Chat history is incomplete, hard to verify and not safe as a development source of truth.
Date: 2026-04-24
Status: accepted

## Decision HV-D002: Branch-per-task workflow
Decision: Every agent works on a task-specific branch using `agent/<agent-name>/<task-id>-<task-slug>`.
Reason: Prevents uncontrolled edits to `main`, enables review, supports rollback and isolates concurrent work.
Date: 2026-04-24
Status: accepted

## Decision HV-D003: Human-controlled merge
Decision: Agents may open pull requests but should not merge to `main` without explicit human approval.
Reason: Keeps release authority with the operator and prevents unreviewed autonomous changes.
Date: 2026-04-24
Status: accepted

## Decision HV-D004: Verification before done
Decision: A task is not done unless verification commands are run or the reason they cannot run is documented.
Reason: Prevents polished but unverified work from being treated as complete.
Date: 2026-04-24
Status: accepted
