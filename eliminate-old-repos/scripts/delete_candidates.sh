#!/usr/bin/env bash
set -euo pipefail

ORG="${ORG:-snyk-code-support}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
OUT_TSV="${OUT_TSV:-candidates.tsv}"

if [[ -z "${TOKEN}" ]]; then
  echo "Missing token. Set GITHUB_TOKEN (preferred) or GH_TOKEN." >&2
  exit 2
fi
if [[ ! -f "${OUT_TSV}" ]]; then
  echo "Missing candidates file: ${OUT_TSV}" >&2
  exit 2
fi

candidate_count="$(( $(wc -l < "${OUT_TSV}") - 1 ))"
echo "About to DELETE ${candidate_count} repos from ${ORG} listed in ${OUT_TSV}."
echo "Type exactly: DELETE ${ORG} ${candidate_count}"
read -r confirmation
if [[ "${confirmation}" != "DELETE ${ORG} ${candidate_count}" ]]; then
  echo "Aborted."
  exit 3
fi

api_del() {
  curl -sS -X DELETE -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" "$@"
}

tail -n +2 "${OUT_TSV}" | cut -f1 | while IFS= read -r full_name; do
  repo="${full_name#${ORG}/}"
  [[ -z "${repo}" || "${repo}" == "${full_name}" ]] && { echo "Skipping unexpected full_name: ${full_name}" >&2; continue; }
  echo "Deleting ${full_name}..."
  api_del "https://api.github.com/repos/${ORG}/${repo}" >/dev/null
done

echo "Done."
