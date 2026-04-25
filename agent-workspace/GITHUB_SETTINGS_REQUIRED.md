# Required GitHub Settings

These settings complete the operational-grade workflow. Some cannot be fully enforced by repository files and must be configured in GitHub Settings.

## Branch protection for `main`
Go to:

Settings > Branches > Add branch protection rule

Branch name pattern:

```text
main
```

Enable:

- Require a pull request before merging
- Require approvals: 1
- Dismiss stale pull request approvals when new commits are pushed
- Require review from Code Owners
- Require status checks to pass before merging
- Require branches to be up to date before merging
- Require conversation resolution before merging
- Do not allow bypassing the above settings

Required checks after they appear on PR #1:

- Build, test and scan
- Typecheck, test and build
- Secret scan
- Agent workspace check
- Vercel, only after Vercel environment variables are correctly configured

## Repository security settings
Go to:

Settings > Code security and analysis

Enable where available:

- Dependency graph
- Dependabot alerts
- Dependabot security updates
- Secret scanning
- Push protection

## Agent access rule
Agents may create branches and pull requests. Agents should not merge to `main` without explicit operator approval.

## First verification after this PR
After this PR is ready:

1. Confirm GitHub Actions starts.
2. Review failed checks if any.
3. Repair the branch until all checks pass or the blocker is documented.
4. Enable branch protection rules using the exact check names from the PR.
