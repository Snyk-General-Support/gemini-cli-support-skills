# Skills GitHub repository

## Canonical (public) repo

Use this repository for Gemini CLI support skills so **unauthenticated `git pull` works** (no private-org token needed for read access):

- **Web:** `https://github.com/Snyk-General-Support/gemini-cli-support-skills`
- **Clone URL (HTTPS):** `https://github.com/Snyk-General-Support/gemini-cli-support-skills.git`

(Settings URL: `https://github.com/Snyk-General-Support/gemini-cli-support-skills/settings` — org admins manage visibility and access there.)

## First-time setup

Clone into the directory you pass to the update skill as `SKILL_REPO`:

```bash
git clone https://github.com/Snyk-General-Support/gemini-cli-support-skills.git ~/Documents/Snyk/gemini-cli-support-skills
```

## Switch an existing clone from a private remote

From inside your local skills repo:

```bash
git remote -v
git remote set-url origin https://github.com/Snyk-General-Support/gemini-cli-support-skills.git
git fetch origin
git branch -u origin/main main   # adjust branch name if yours differs
git pull --ff-only
```

## Token requirement

- **Public repo:** `git fetch` / `git pull` over HTTPS usually work **without** `GITHUB_TOKEN`.
- **Private repo:** set `GITHUB_TOKEN` (or `GH_TOKEN`); the update script will use it for HTTPS remotes.

We cannot create GitHub repositories or change org/repo settings from this project—only document URLs and local `git` commands.
