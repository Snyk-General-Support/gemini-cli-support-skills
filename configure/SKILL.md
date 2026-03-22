---
name: configure-tokens
description: Ensures GITHUB_TOKEN and SNYK_TOKEN are set in the correct shell profile (zsh or bash), creates ~/Desktop/cases for support case work, exports SNYK_CASES_DIR, validates tokens when possible, and prompts only for missing or invalid values. Use when setting up a machine for Snyk/GitHub skills or when the user asks to configure API tokens and case folders.
---

# Configure tokens

Ensure **`GITHUB_TOKEN`** and **`SNYK_TOKEN`** exist in the user’s shell profile so other skills can rely on them. Use **`.zprofile`** for **zsh** and **`.bash_profile`** for **bash** (typical on macOS).

## Variables

| Variable        | Purpose                          |
|-----------------|----------------------------------|
| `GITHUB_TOKEN`  | GitHub API / `gh` / git HTTPS    |
| `SNYK_TOKEN`    | Snyk CLI and Snyk API            |
| `SNYK_CASES_DIR`| Directory where support **cases** are stored (written by configure) |

Optional: `GH_TOKEN` is treated as an alias for GitHub when reading the profile; the script normalizes to `GITHUB_TOKEN` in the profile.

## Cases directory

- **Default path:** `~/Desktop/cases` (i.e. `$HOME/Desktop/cases` on macOS).
- On each run, configure **creates that folder** if it does not exist and sets **`SNYK_CASES_DIR`** in the same managed profile block as the tokens so other skills can use `"${SNYK_CASES_DIR}"` (or `$SNYK_CASES_DIR`) for per-case subfolders.
- Override the path for the script only: `CASES_ROOT=/custom/path ./configure/scripts/configure_tokens.sh` (the profile will still export `SNYK_CASES_DIR` pointing at that path).

## When this skill runs

1. **Detect profile file** from the user’s login shell (`$SHELL`): `zsh` → `~/.zprofile`, `bash` → `~/.bash_profile`. Override with `PROFILE_FILE` if needed.
2. **Read** existing `export GITHUB_TOKEN=…` and `export SNYK_TOKEN=…` from that file (if present).
3. **Validate** each token when possible:
   - **GitHub**: `GET https://api.github.com/user` with `Authorization: Bearer <token>`.
   - **Snyk**: `GET https://api.snyk.io/v1/user` with `Authorization: token <token>`.
4. If a value is **missing**, **empty**, or **validation fails**, **prompt** the user for a new value and write it to the profile.
5. If a value **exists and validates**, **skip** that variable and continue.
6. **Ensure the cases directory** exists and **write `SNYK_CASES_DIR`** into the managed profile block (refreshed every successful run).

## Script (recommended)

Run the interactive helper from the repo root:

```bash
chmod +x configure/scripts/configure_tokens.sh
./configure/scripts/configure_tokens.sh
```

Optional:

```bash
PROFILE_FILE="$HOME/.zprofile" ./configure/scripts/configure_tokens.sh
```

If you cannot reach GitHub/Snyk APIs (offline/air-gapped), skip HTTP checks (non-empty token only):

```bash
SKIP_VALIDATION=1 ./configure/scripts/configure_tokens.sh
```

The script:

- Creates the profile file if it does not exist.
- Creates **`~/Desktop/cases`** (or **`CASES_ROOT`**) and exports **`SNYK_CASES_DIR`** in the managed block.
- Adds or updates a marked block (`# --- snyk-skills-tokens (managed by configure skill) ---`) so repeated runs do not duplicate lines.
- Tells the user to `source` the profile or open a new terminal.

## Agent behavior (no script)

If the user cannot run the script, the agent should:

1. Determine profile path from `$SHELL` (or ask).
2. Inspect the profile for existing exports.
3. For each missing or invalid token, ask once, then append or replace exports in the marked block.
4. Never echo full tokens back in chat; confirm only that they were set.
5. Ensure **`~/Desktop/cases`** exists (or the path the user chose via `CASES_ROOT`) and that **`SNYK_CASES_DIR`** is documented in the profile block after a successful configure.

## Undo (demos / misconfiguration)

To remove the configure-managed token block from the profile, use the **reset-configure-tokens** skill: `reset/SKILL.md` and `reset/scripts/reset_configure_tokens.sh`.

## References

- Shell profile details: `references/profiles.md`
