#!/usr/bin/env bash
set -euo pipefail

ORG="${ORG:-snyk-code-support}"
AGE_MONTHS="${AGE_MONTHS:-6}"
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
ALLOWLIST_FILE="${ALLOWLIST_FILE:-allowlist.json}"
OUT_TSV="${OUT_TSV:-candidates.tsv}"

if [[ -z "${TOKEN}" ]]; then
  echo "Missing token. Set GITHUB_TOKEN (preferred) or GH_TOKEN." >&2
  exit 2
fi

if [[ ! -f "${ALLOWLIST_FILE}" ]]; then
  echo "Missing allowlist file: ${ALLOWLIST_FILE}" >&2
  exit 2
fi

# Validate allowlist.json shape early (expects a JSON array of strings)
python3 - <<'PY'
import json, os, sys
path = os.environ["ALLOWLIST_FILE"]
with open(path, "r", encoding="utf-8") as f:
  data = json.load(f)
if not isinstance(data, list) or not all(isinstance(x, str) for x in data):
  raise SystemExit("allowlist must be a JSON array of strings (full repo names like owner/name)")
PY

# Load allowlist.json into an in-memory set for fast lookups
declare -A ALLOW_SET=()
while IFS= read -r full_name; do
  [[ -z "${full_name}" ]] && continue
  ALLOW_SET["${full_name}"]=1
done < <(
  python3 - <<'PY'
import json, os
path = os.environ["ALLOWLIST_FILE"]
with open(path, "r", encoding="utf-8") as f:
  data = json.load(f)
for x in data:
  if isinstance(x, str) and x:
    print(x)
PY
)

# Cutoff date in UTC ISO-8601 (macOS `date` preferred; Python stdlib fallback)
if date -u -v-"${AGE_MONTHS}"m +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
  CUTOFF="$(date -u -v-"${AGE_MONTHS}"m +"%Y-%m-%dT%H:%M:%SZ")"
else
  CUTOFF="$(
  python3 - <<'PY'
import os
from datetime import datetime, timedelta, timezone

# Fallback uses 30-day months approximation.
age_months = int(os.environ.get("AGE_MONTHS", "6"))
cutoff = datetime.now(timezone.utc) - timedelta(days=30 * age_months)
print(cutoff.strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
  )"
fi

api() {
  curl -sS -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" "$@"
}

is_allowlisted() {
  local full_name="$1"
  [[ -n "${ALLOW_SET[${full_name}]:-}" ]]
}

echo -e "full_name\tcreated_at\tpushed_at\tupdated_at\tarchived\tprivate\thtml_url" > "${OUT_TSV}"

page=1
while :; do
  resp="$(api "https://api.github.com/orgs/${ORG}/repos?per_page=100&page=${page}&type=all&sort=updated&direction=asc")"
  count="$(python3 - <<'PY'
import json,sys
data=json.load(sys.stdin)
print(len(data) if isinstance(data,list) else 0)
PY
<<<"${resp}")"

  [[ "${count}" -eq 0 ]] && break

  CUTOFF="${CUTOFF}" python3 - <<'PY'
import json, os, sys
from datetime import datetime, timezone

cutoff = datetime.strptime(os.environ["CUTOFF"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
data = json.load(sys.stdin)

def parse(ts):
  if not ts:
    return None
  return datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)

for r in data:
  full_name = r.get("full_name","")
  created_at = r.get("created_at")
  pushed_at = r.get("pushed_at")
  updated_at = r.get("updated_at")
  archived = r.get("archived", False)
  private = r.get("private", False)
  html_url = r.get("html_url","")

  c = parse(created_at)
  p = parse(pushed_at)
  eligible = (c and c < cutoff) or (p and p < cutoff)
  if not eligible:
    continue

  print("\t".join([
    full_name,
    created_at or "",
    pushed_at or "",
    updated_at or "",
    "true" if archived else "false",
    "true" if private else "false",
    html_url,
  ]))
PY
<<<"${resp}" >> "${OUT_TSV}"

  page="$((page+1))"
done

tmp="$(mktemp)"
{
  head -n 1 "${OUT_TSV}"
  tail -n +2 "${OUT_TSV}" | while IFS=$'\t' read -r full_name rest; do
    if is_allowlisted "${full_name}"; then
      continue
    fi
    printf "%s\t%s\n" "${full_name}" "${rest}"
  done
} > "${tmp}"
mv "${tmp}" "${OUT_TSV}"

echo "Cutoff: ${CUTOFF}"
echo "Wrote: ${OUT_TSV}"
echo "Candidate count: $(( $(wc -l < "${OUT_TSV}") - 1 ))"
