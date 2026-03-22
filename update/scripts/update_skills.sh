#!/usr/bin/env bash
set -euo pipefail

SKILL_REPO="${SKILL_REPO:-}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
REMOTE_NAME="${GIT_REMOTE_NAME:-origin}"

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

echo "Done. Skills are up to date."
