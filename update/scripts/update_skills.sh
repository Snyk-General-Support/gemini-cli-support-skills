#!/usr/bin/env bash
set -euo pipefail

SKILL_REPO="${SKILL_REPO:-}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
REMOTE_NAME="${GIT_REMOTE_NAME:-origin}"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.cursor/skills}"

if [[ -z "${SKILL_REPO}" ]]; then
  echo "SKILL_REPO is required (path to local skill repo)." >&2
  exit 2
fi

if [[ ! -d "${SKILL_REPO}/.git" ]]; then
  echo "SKILL_REPO does not look like a git repo: ${SKILL_REPO}" >&2
  exit 2
fi

cd "${SKILL_REPO}"

current_branch="$(git rev-parse --abbrev-ref HEAD)"
remote_url="$(git remote get-url "${REMOTE_NAME}")"

echo "Updating skill repo:"
echo "  Path   : ${SKILL_REPO}"
echo "  Branch : ${current_branch}"
echo "  Remote : ${REMOTE_NAME} (${remote_url})"

restore_url=""
cleanup() {
  if [[ -n "${restore_url}" ]]; then
    git remote set-url "${REMOTE_NAME}" "${restore_url}"
  fi
}
trap cleanup EXIT

# Private HTTPS GitHub: inject token for this fetch/pull only (then restore URL).
if [[ -n "${TOKEN}" ]] \
  && [[ "${remote_url}" == https://github.com/* ]] \
  && [[ "${remote_url}" != https://*@github.com/* ]]; then
  restore_url="${remote_url}"
  auth_url="${remote_url/https:\/\/github.com/https:\/\/${TOKEN}@github.com}"
  git remote set-url "${REMOTE_NAME}" "${auth_url}"
elif [[ -z "${TOKEN}" ]] && [[ "${remote_url}" == https://github.com/* ]]; then
  echo "No GITHUB_TOKEN/GH_TOKEN set; using unauthenticated HTTPS (OK for public repos)." >&2
fi

echo "Fetching latest changes..."
git fetch "${REMOTE_NAME}" --prune

echo "Pulling (fast-forward only)..."
git pull --ff-only "${REMOTE_NAME}" "${current_branch}"

echo "Syncing skills into ${INSTALL_DIR}..."

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync not found; falling back to cp -a (no delete). Please install rsync for exact sync." >&2
  mkdir -p "${INSTALL_DIR}"
  for d in "${SKILL_REPO}"/*; do
    [[ -d "${d}" ]] || continue
    if [[ -f "${d}/SKILL.md" ]]; then
      name="$(basename "${d}")"
      cp -a "${d}" "${INSTALL_DIR}/${name}"
      echo "Installed: ${name}"
    fi
  done
else
  mkdir -p "${INSTALL_DIR}"
  installed_count=0
  for d in "${SKILL_REPO}"/*; do
    [[ -d "${d}" ]] || continue
    if [[ -f "${d}/SKILL.md" ]]; then
      name="$(basename "${d}")"
      # Sync directory contents to match the repo (includes new skills + updates)
      rsync -a --delete "${d}/" "${INSTALL_DIR}/${name}/" || true
      installed_count=$((installed_count+1))
      echo "Installed/updated: ${name}"
    fi
  done
  echo "Skill sync complete (${installed_count} skills processed)."
fi

echo "Done. Skills are up to date."
