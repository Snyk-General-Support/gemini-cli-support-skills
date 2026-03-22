---
name: update-skills
description: Updates local Cursor skill repositories by pulling the latest changes from a remote GitHub repo. Use when syncing skills to the newest version; prefers the public Snyk-General-Support gemini-cli-support-skills repo when a private remote blocks scripts.
---

# Update Skills

This skill keeps your local skill repositories up to date by pulling the latest changes from a remote GitHub repository.

## Canonical skills repository (public)

Use the **public** repo so scripts work without access to a private organization:

| | |
|--|--|
| **Repo** | `Snyk-General-Support/gemini-cli-support-skills` |
| **HTTPS** | `https://github.com/Snyk-General-Support/gemini-cli-support-skills.git` |

Clone or point `origin` at that URL. Details: [references/remote.md](references/remote.md).

## Assumptions

- You have a **Git clone** of the skills repo locally (for example `~/Documents/Snyk/gemini-cli-support-skills`).
- `origin` points at GitHub (HTTPS or SSH).
- For **private** remotes only: set `GITHUB_TOKEN` or `GH_TOKEN`. **Public** remotes do not require a token.

## Configuration

- **Target directory (required):** local path to the skills repo → `SKILL_REPO`.
- **Optional:** `GIT_REMOTE_NAME` (default: `origin`).
- **Token (optional for public repos):** `GITHUB_TOKEN` or `GH_TOKEN`.

## Workflow

1. **Ensure `origin` uses the public repo** (if migrating from a private remote): see [references/remote.md](references/remote.md).
2. **Set `SKILL_REPO`** to your local clone path.
3. **Token:** export `GITHUB_TOKEN` only if `origin` is private or your environment requires auth.
4. **Run the update script:**

   ```bash
   chmod +x update/scripts/update_skills.sh
   SKILL_REPO=~/Documents/Snyk/gemini-cli-support-skills ./update/scripts/update_skills.sh
   ```

5. **Verify:** script prints branch, remote URL, and fetch/pull result.

## Script location

- `update/scripts/update_skills.sh`

Behavior:

- Validates `SKILL_REPO` is a git repo.
- For **HTTPS** `https://github.com/...` without embedded credentials: if a token is set, temporarily sets `origin` to `https://TOKEN@github.com/...` for `fetch`/`pull`, then restores the original URL.
- If **no token** is set: runs normal `git fetch` / `git pull --ff-only` (works for **public** repos).

## References

- Remote URL, clone, and `git remote set-url`: [references/remote.md](references/remote.md)
