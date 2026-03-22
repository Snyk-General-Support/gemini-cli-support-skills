---
name: reset-configure-tokens
description: Removes the configure-tokens managed shell profile block (GITHUB_TOKEN, SNYK_TOKEN, SNYK_CASES_DIR). Use for demos or undoing misconfiguration. Never deletes the Desktop cases folder or case files—only profile exports.
---

# Reset configure tokens

Hard-reset **only** the configuration written by the **configure-tokens** skill: the marked block in your login profile that exports `GITHUB_TOKEN`, `SNYK_TOKEN`, and `SNYK_CASES_DIR`.

**Important:** This skill **must not** delete the **cases folder on the Desktop** (default **`~/Desktop/cases`**) or anything inside it. Only the **profile exports** are removed; **all case data on disk stays**.

Use this for **scratch demos**, **bad paste** recovery, or **switching accounts**—then run configure again if you need new tokens (configure will recreate `SNYK_CASES_DIR` and can reuse the existing folder).

## What gets removed

- The block between these markers (same as configure uses):

  - `# --- snyk-skills-tokens (managed by configure skill) ---`
  - `# --- end snyk-skills-tokens ---`

## What is **not** removed

- **`~/Desktop/cases`** (or any other cases directory on disk)—**never delete** this folder or its contents as part of reset.
- Any `export GITHUB_TOKEN=…` or `export SNYK_TOKEN=…` **outside** that block (manual edits stay).
- Other skills’ files, git remotes, or Snyk CLI config (`~/.config/configstore/snyk.json`, etc.)—only the **profile block** above.

## Profile file

Same rules as configure:

- **zsh:** `~/.zprofile` (or `PROFILE_FILE`)
- **bash:** `~/.bash_profile` (or `PROFILE_FILE`)

## Workflow

1. Run the reset script (it asks for confirmation unless you set `RESET_CONFIRM=yes`):

   ```bash
   chmod +x reset/scripts/reset_configure_tokens.sh
   ./reset/scripts/reset_configure_tokens.sh
   ```

2. Open a **new terminal** or run `source ~/.zprofile` / `source ~/.bash_profile` so the old exports are gone from the current session.

## Agent behavior

- Explain that only the **configure-managed block** is removed.
- **Do not** delete, empty, or “clean up” **`~/Desktop/cases`** (or case subfolders); that data is intentionally preserved.
- Require explicit user confirmation before running the script (or ensure they typed `RESET` in the script prompt).
- Do not print previous token values from the profile.

## References

- What configure writes: `../configure/SKILL.md` and `../configure/scripts/configure_tokens.sh`
- Scope notes: `references/scope.md`
