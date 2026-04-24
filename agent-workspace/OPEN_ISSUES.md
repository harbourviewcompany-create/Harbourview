# Open Issues

## Issue HV-I001
Severity: High
File/path: project-wide
Problem: Production readiness has not been verified through the new CI workflow yet.
Evidence: This task is creating the workflow and has not observed a completed run.
Impact: The repo cannot be treated as release-ready until checks pass.
Proposed fix: Open PR, let GitHub Actions run and repair any failures.
Status: open
Owner/next agent: next engineering agent

## Issue HV-I002
Severity: High
File/path: Supabase project/dashboard and migrations
Problem: RLS and workspace isolation require dedicated verification.
Evidence: This operating-layer task has not exported or reviewed the full live Supabase schema.
Impact: Security-sensitive flows may be unsafe until proven otherwise.
Proposed fix: Run a dedicated Supabase/RLS hardening task.
Status: open
Owner/next agent: next security-hardening agent

## Issue HV-I003
Severity: Medium
File/path: GitHub repository settings
Problem: Branch protection and required status checks must be enabled after the workflow exists.
Evidence: Branch protection is a repository setting, not fully enforceable through the files added here.
Impact: Agents could still bypass the intended PR gate if repository settings are not configured.
Proposed fix: Enable branch protection on `main`, require PR review and require the Verify workflow checks.
Status: open
Owner/next agent: Tyler/operator
