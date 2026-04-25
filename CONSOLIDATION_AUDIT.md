# Harbourview Consolidation Audit

Date: 2026-04-25

## Scope

Comparison between:

1. Canonical Git repository (Production Spine)
2. XFILE archive dump (HV - XFILE 425.zip)

---

## 1. Canonical repository (verified)

The GitHub repository contains a complete, structured system:

- Next.js application
- Supabase integration
- SQL migrations (0001 to 0012 via APPLY_ALL.sql)
- RLS enforcement layer
- API routes for signals, sources, dossiers and publishing
- Test suite (Vitest)
- Security and runbook documentation

This is a coherent system designed to be deployed and extended.

---

## 2. XFILE archive (analysis)

The XFILE archive is not a single project.

It is a container of 20+ zip files including:

### CRM prototypes

- harbourview_crm_v1 / v2 / v3
- harbourview_crm_app
- harbourview_crm_source (React/Vite app)
- harbourview_crm_dist (built artifacts)

These represent multiple iterations of a CRM concept using:

- static HTML
- Python backend
- React/Vite frontend
- JSON data stores

They are inconsistent with the current Production Spine architecture.

### Dashboard prototypes

- harbourview_dashboard
- harbourview_dashboard_v5_ready

Early Next.js style UI experiments with limited backend structure.

### Netlify endpoints

- supplier onboarding endpoints (multiple versions)

Standalone serverless deployments using Netlify functions.

Not aligned with current Supabase + Next.js architecture.

### Data assets

- XLSX intelligence pack
- CSV outreach logs
- JSON CRM datasets

These are data, not application code.

---

## 3. Critical conclusion

The XFILE archive is:

- a historical dump
- a collection of experiments
- a set of reference assets

It is NOT a coherent application.

It must NOT replace or overwrite the GitHub repository.

---

## 4. Approved usage of XFILE content

Only the following may be reused:

### A. Data

- CSV / JSON datasets for seeding or enrichment

### B. UI reference

- specific components or layouts from dashboard prototypes

### C. CRM concepts

- feature ideas (contacts, pipeline, targets, intelligence views)

---

## 5. Explicit exclusions

Do NOT import:

- entire CRM builds
- Netlify endpoint projects
- dist builds
- duplicated versions (v1, v2, v3 chains)
- any zip bundle as-is

---

## 6. Final state

The system is now considered consolidated under:

harbourviewcompany-create/harbourview-platform

All further work proceeds from this repository only.
