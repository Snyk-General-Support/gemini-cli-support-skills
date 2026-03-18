---
name: eliminate-old-repos
description: Deletes GitHub repositories in an organization when they are older than a threshold (default 6 months) based on created_at OR pushed_at. Use when cleaning up old repos in `snyk-code-support`, especially when the user requests deleting old repositories and provides (or can provide) a GitHub token.
---

# Eliminate Old Repos

Delete repositories from a GitHub organization when either `created_at` **or** `pushed_at` is older than a threshold (default: 6 months).

This workflow is **destructive**. It uses the GitHub REST API via `curl` and requires an allowlist to exempt repos that must never be deleted.

## Inputs (defaults)

- **ORG**: `snyk-code-support`
- **AGE_MONTHS**: `6`
- **Eligibility rule**: delete if `created_at < cutoff` OR `pushed_at < cutoff`
- **Allowlist**: JSON list of repo full names to preserve (required)

## Authentication requirements

You must have a token in `GITHUB_TOKEN` (preferred) or `GH_TOKEN`.

The token must be authorized to delete repos in the target org (classic PAT needs `delete_repo`; fine-grained tokens must have repo administration permissions for the repos in scope).

## Required safety rule

1. **Never delete** a repo that is present in the allowlist JSON (exact match).
2. **Always generate a candidate report first**, then require a **typed confirmation phrase** before any DELETE requests.

## Workflow (copy/paste)

### 1) Create an allowlist file (required)

Create `allowlist.json` as a JSON array of repo full names (`owner/name`). Any repo listed here is **excluded** from deletion.

Example:

```bash
cat > eliminate-old-repos/allowlist.json <<'EOF'
[
  "snyk-code-support/do-not-delete"
]
EOF
```

### 2) Inventory candidates (no deletions)

Run the inventory script to generate `candidates.tsv`:

```bash
chmod +x eliminate-old-repos/scripts/*.sh
ALLOWLIST_FILE=eliminate-old-repos/allowlist.json
./eliminate-old-repos/scripts/inventory_candidates.sh
```

Optional overrides:

```bash
ORG=snyk-code-support AGE_MONTHS=6 OUT_TSV=candidates.tsv ./eliminate-old-repos/scripts/inventory_candidates.sh
```

### 3) Delete candidates (requires explicit confirmation)

Run the delete script (it will prompt for an explicit confirmation phrase):

```bash
./eliminate-old-repos/scripts/delete_candidates.sh
```

Optional overrides:

```bash
ORG=snyk-code-support OUT_TSV=candidates.tsv ./eliminate-old-repos/scripts/delete_candidates.sh
```

## References

- Token/auth details: `references/auth.md`
- Allowlist JSON format: `references/allowlist.md`

## Output expectations

When using this skill:

- Produce a **candidate report** (the `candidates.tsv` contents summary: count + top/bottom examples).
- Clearly state the **cutoff timestamp** and the **eligibility rule**.
- Confirm that the **allowlist was applied** and how many repos were exempted.
- Only proceed to deletion after the explicit confirmation phrase is provided.

