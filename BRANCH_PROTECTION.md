# Branch Protection Setup

I cannot enforce branch protection from this repository without GitHub settings/API access. Configure it before production.

## GitHub UI steps

1. Open GitHub repository `harbourviewcompany-create/Harbourview`.
2. Go to Settings > Branches.
3. Add branch protection rule for `main`.
4. Enable:
   - Require a pull request before merging.
   - Require approvals: 1 minimum, 2 for security-sensitive changes if available.
   - Dismiss stale pull request approvals when new commits are pushed.
   - Require review from Code Owners if CODEOWNERS is configured.
   - Require status checks to pass before merging.
   - Require branches to be up to date before merging.
   - Required status check: `Build, test and scan` from `Security CI`.
   - Require conversation resolution before merging.
   - Require signed commits if available.
   - Do not allow force pushes.
   - Do not allow deletions.
   - Include administrators.
5. Save changes.

## GitHub CLI equivalent

Run from an account with repository admin permission:

```bash
gh api \
  --method PUT \
  repos/harbourviewcompany-create/Harbourview/branches/main/protection \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Build, test and scan"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
```

If GitHub rejects `require_last_push_approval`, remove that field and rerun.
