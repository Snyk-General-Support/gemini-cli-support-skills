#!/usr/bin/env bash
set -euo pipefail

REPO=""
CASE_DIR=""

usage() {
  cat <<EOF
usage: collect_pr_check_context.sh --repo <owner/repo or repo> --case-dir <path>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --case-dir) CASE_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "${REPO}" || -z "${CASE_DIR}" ]]; then
  usage >&2
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required." >&2
  exit 2
fi

mkdir -p "${CASE_DIR}"

pr_json="${CASE_DIR}/github-prs.json"
checks_json="${CASE_DIR}/github-check-runs.json"
summary_json="${CASE_DIR}/pr-check-context.json"

# Pull latest PR info (best effort)
gh pr list --repo "${REPO}" --limit 20 --json number,title,state,url,headRefName,baseRefName,createdAt,updatedAt > "${pr_json}" || echo "[]" > "${pr_json}"

# Extract latest PR number
latest_pr_number="$(jq -r '.[0].number // empty' "${pr_json}" 2>/dev/null || true)"

if [[ -n "${latest_pr_number}" ]]; then
  # Check runs via commits endpoint
  head_sha="$(gh pr view "${latest_pr_number}" --repo "${REPO}" --json commits --jq '.commits[-1].oid' 2>/dev/null || true)"
  if [[ -n "${head_sha}" ]]; then
    gh api "repos/${REPO}/commits/${head_sha}/check-runs" > "${checks_json}" || echo '{}' > "${checks_json}"
  else
    echo '{}' > "${checks_json}"
  fi
else
  echo '{}' > "${checks_json}"
fi

jq -n \
  --arg repo "${REPO}" \
  --arg case_dir "${CASE_DIR}" \
  --arg latest_pr "${latest_pr_number}" \
  --arg pr_file "${pr_json}" \
  --arg checks_file "${checks_json}" \
  '{
    repo: $repo,
    case_dir: $case_dir,
    latest_pr_number: ($latest_pr | if .=="" then null else tonumber end),
    pr_file: $pr_file,
    checks_file: $checks_file
  }' > "${summary_json}"

echo "Wrote:"
echo "  ${pr_json}"
echo "  ${checks_json}"
echo "  ${summary_json}"

