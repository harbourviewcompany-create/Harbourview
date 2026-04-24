# Harbourview Production Spine — Pre-Run Setup
## What to do before `npm test`

---

### 1. Supabase project

Use a **fresh** Supabase project (not the System A project at `fgdrvqqezdiraqyuofte.supabase.co`).
The two schemas are incompatible. System A must not be touched.

Create a new project at https://supabase.com/dashboard → New project.
Note: Project URL, `anon` key, and `service_role` key from Project Settings → API.

---

### 2. Create auth users

In your Supabase dashboard → Authentication → Users → Add user (or use the CLI):

```bash
supabase auth admin create-user \
  --email admin@harbourview.io \
  --password <choose-strong-password> \
  --user-metadata '{"full_name":"HV Admin"}'

supabase auth admin create-user \
  --email analyst@harbourview.io \
  --password <choose-strong-password> \
  --user-metadata '{"full_name":"HV Analyst"}'
```

Copy both resulting UUIDs — you need them for step 3.

> If you apply migration 0010 (auth trigger) **before** creating users, the
> trigger fires on signup and creates profile rows automatically. If you
> create users **before** applying migrations, the profile insert in 0009
> handles it. Either order works — both paths have ON CONFLICT guards.

---

### 3. Update seed UUIDs

Open `migrations/0009_seed_data.sql` and replace the two placeholder values:

```sql
\set admin_id    '<UUID from auth dashboard for admin@harbourview.io>'
\set analyst_id  '<UUID from auth dashboard for analyst@harbourview.io>'
```

All other UUIDs in 0009 are fixed and deterministic — do not change them.

---

### 4. Apply migrations

Using Supabase SQL editor or CLI, apply in this exact order:

```
0001_create_enums.sql                        ← from original files (files (2).zip)
0002_create_profiles_and_workspaces.sql      ← from original files
0003_create_sources_and_source_documents.sql ← from original files
0004_create_signals_and_evidence.sql         ← from original files
0005_create_review_queue.sql                 ← CORRECTED (this pack)
0006_create_dossiers_and_publish_events.sql  ← CORRECTED (this pack)
0006b_amend_dossier_immutability_trigger.sql ← NEW (this pack)
0007_create_audit_events.sql                 ← from original files
0008_create_rls_policies.sql                 ← CORRECTED (this pack)
0009_seed_data.sql                           ← CORRECTED (this pack) — dev only
0010_create_auth_trigger.sql                 ← NEW (this pack)
0011_workspace_membership_rls.sql            ← NEW (this pack)
0012_germany_operator_seed.sql               ← NEW (this pack) — OI-3 real data, dev only
```

CLI shortcut (run from project root):
```bash
for f in migrations/000*.sql; do
  echo "Applying $f..."
  supabase db push --file "$f"
done
```

Or paste each file into the Supabase SQL editor in order.

After applying 0009, run the verification query at the bottom of that file
to confirm the seed landed correctly.

---

### 5. Configure environment

Create `.env.local` in the project root (copy from `.env.example` and fill in):

```bash
# Supabase — get from Project Settings → API
NEXT_PUBLIC_SUPABASE_URL=https://<your-project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<anon-key>
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>

# Test credentials — must match what you set in step 2
TEST_ADMIN_EMAIL=admin@harbourview.io
TEST_ADMIN_PASSWORD=<password-set-in-step-2>
TEST_ANALYST_EMAIL=analyst@harbourview.io
TEST_ANALYST_PASSWORD=<password-set-in-step-2>

# Local dev server URL for feed route tests
APP_URL=http://localhost:3000
```

---

### 6. Install dependencies and start dev server

```bash
npm install
npm run dev        # starts Next.js on http://localhost:3000
```

Leave this running in one terminal.

---

### 7. Run the golden-path test suite

In a second terminal:

```bash
npm test
```

Expected: **10 golden-path tests + 8 negative-path tests = 18 total, all pass.**

Key negative paths to watch:
- **N1** — approve without evidence → blocked by DB trigger
- **N3** — mutate published dossier → blocked by immutability trigger
- **N4** — revoked token → feed returns 410 (INSERT-based revocation model)
- **N7** — analyst cannot update review_queue_items → blocked by RLS
- **N8** — double revoke → throws "already been revoked"

---

### 8. After tests pass — rotate the seed token

The seed's `api_token` is a fixed placeholder:
`hvfeed_seed_dev_only_00000000000000000000000000000090`

Before any real integration work, revoke it via `revokePublishEvent()` and
re-publish via `publishDossier()` to get a cryptographically random token
(`hvfeed_` + 48 random hex chars).

---

### Open items

All open items are now closed.

| ID  | Item                              | Status                                                      |
|-----|-----------------------------------|-------------------------------------------------------------|
| OI-1 | Auth trigger                    | ✅ Closed — migration 0010                                  |
| OI-2 | Multi-workspace client membership | ✅ Closed — migration 0011                                |
| OI-3 | Germany operator real seed      | ✅ Closed — migration 0012 (5 operators, sourced from workbook) |

All other OIs are closed.
