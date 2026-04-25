# Rollback Plan

## Local rollback
Use git to return to a known good state.

```bash
git status
git log --oneline -10
git restore <path>
git reset --hard <commit-sha>
```

Use `git reset --hard` only when local uncommitted work can be discarded.

## Pull request rollback
- Close the PR if the change is unsafe.
- Push a corrective commit if the change is salvageable.
- Convert to draft if the work needs more repair.

## Main branch rollback
Use a revert commit instead of rewriting public history.

```bash
git revert <commit-sha>
```

## Database rollback
- Prefer rollback migrations or documented SQL recovery.
- Do not apply destructive rollback SQL without operator approval.
- Record affected tables, policies and data risk in `HANDOFF_LOG.md`.

## Deployment rollback
- Revert to last known good deployment in the deployment provider.
- Confirm environment variables are still correct.
- Confirm database compatibility with the deployed code.

## Last known good state
Commit: current `main` before PR #1 merge
Date: 2026-04-24
Verification status: pending final PR checks
