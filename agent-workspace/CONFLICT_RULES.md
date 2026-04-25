# Conflict Rules

## Resolution hierarchy
When agents, docs or prior notes conflict, resolve in this order:

1. Passing CI, build, typecheck and tests.
2. Verified runtime behavior.
3. Security and data-safety requirements.
4. `DECISIONS.md`.
5. `MIGRATION_POLICY.md` and `SECRETS_POLICY.md`.
6. Existing architecture and file conventions.
7. Minimal-change principle.
8. Agent opinion.

## Rules
- Do not overwrite another agent's work without checking `LOCK.md` and branch state.
- Do not treat chat history as authoritative unless the decision is reflected in repo files.
- If code and handoff docs disagree, inspect the code and update the stale handoff doc.
- If two agents touch the same files, pause and resolve through the pull request or `HANDOFF_LOG.md`.
- If a change creates a security regression, security wins over speed and convenience.
- If a change breaks tests or build, the branch is not ready to merge.

## Merge conflict handling
1. Pull or compare against latest `main`.
2. Preserve the smallest correct change.
3. Re-run verification commands.
4. Update `HANDOFF_LOG.md` with what was resolved.
5. Do not merge until CI is green or failure is explicitly accepted by the operator.
