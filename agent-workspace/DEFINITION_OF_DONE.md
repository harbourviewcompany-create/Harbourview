# Definition of Done

A task is not complete unless all applicable items are satisfied.

## Required
- [ ] Task ID exists in `TASK_INDEX.md`.
- [ ] Work happened on a task-specific branch, not directly on `main`.
- [ ] Scope stayed inside `CURRENT_TASK.md` unless the task was updated.
- [ ] Code or config changes are implemented.
- [ ] Relevant tests are added or updated where practical.
- [ ] Verification commands are run, or the reason they cannot run is documented.
- [ ] Build status is recorded.
- [ ] Typecheck status is recorded.
- [ ] Test status is recorded.
- [ ] Security impact is considered.
- [ ] Docs or README are updated if workflow changed.
- [ ] Handoff files are updated.
- [ ] Known limitations are documented.
- [ ] One next step is clearly stated.

## Security-sensitive tasks
For auth, data access, publishing, API routes, database policies, migrations or credentials:

- [ ] Ownership/workspace isolation is checked.
- [ ] Client/server boundary is checked.
- [ ] Input validation is checked.
- [ ] Logging avoids sensitive data.
- [ ] Public access paths are explicitly justified.
- [ ] Rollback path is documented.

## Not done if
- Verification was skipped without explanation.
- The branch cannot build.
- The task creates undocumented environment requirements.
- The task weakens security controls.
- The handoff files are stale.
- The agent claims completion without evidence.
