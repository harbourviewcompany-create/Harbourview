# Open Issues

## Issue HV-I001
Severity: High
File/path: project-wide
Problem: Latest PR head has not yet passed all required checks.
Evidence: Branch was reset and HV-001 changes reapplied; final CI run is pending.
Impact: PR #1 cannot be treated as merge-ready until checks pass.
Proposed fix: Let GitHub Actions and Vercel run, inspect failures and repair branch if needed.
Status: open
Owner/next agent: next engineering agent

## Issue HV-I002
Severity: High
File/path: Supabase project/dashboard and migrations
Problem: RLS and workspace isolation require dedicated verification.
Evidence: This operating-layer task has not exported or reviewed the full live Supabase schema.
Impact: Security-sensitive flows may be unsafe until proven otherwise.
Proposed fix: Run HV-002 dedicated Supabase/RLS hardening task.
Status: open
Owner/next agent: next security-hardening agent

## Issue HV-I003
Severity: Medium
File/path: GitHub repository settings
Problem: Branch protection and required status checks must be enabled after the operating layer is merged.
Evidence: Branch protection is a repository setting, not fully enforceable through files alone.
Impact: Agents could bypass the intended PR gate if settings are not configured.
Proposed fix: Enable branch protection on `main`, require PR review and require status checks.
Status: open
Owner/next agent: Tyler/operator
