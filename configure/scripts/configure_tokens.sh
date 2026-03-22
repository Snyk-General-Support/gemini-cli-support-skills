#!/usr/bin/env bash
set -euo pipefail

MARK_BEGIN="# --- snyk-skills-tokens (managed by configure skill) ---"
MARK_END="# --- end snyk-skills-tokens ---"

detect_profile() {
  if [[ -n "${PROFILE_FILE:-}" ]]; then
    echo "${PROFILE_FILE}"
    return
  fi
  local shell_base
  shell_base="$(basename "${SHELL:-/bin/zsh}")"
  case "${shell_base}" in
    zsh)  echo "${HOME}/.zprofile" ;;
    bash) echo "${HOME}/.bash_profile" ;;
    *)
      echo "Unsupported SHELL '${SHELL:-}'; set PROFILE_FILE explicitly." >&2
      exit 2
      ;;
  esac
}

PROFILE="$(detect_profile)"
mkdir -p "$(dirname "${PROFILE}")"
touch "${PROFILE}"

extract_export_value() {
  local key="$1"
  local file="$2"
  [[ -f "${file}" ]] || return 1
  # Last matching export KEY="value" or export KEY='value'
  local line
  line="$(grep -E "^export[[:space:]]+${key}=" "${file}" 2>/dev/null | tail -1 || true)"
  [[ -n "${line}" ]] || return 1
  line="${line#export ${key}=}"
  line="${line#export ${key} =}"
  line="${line%%#*}"
  line="${line//\"/}"
  line="${line//\'/}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  echo "${line}"
}

github_valid() {
  local t="$1"
  [[ -n "${t}" ]] || return 1
  if [[ "${SKIP_VALIDATION:-0}" == "1" ]]; then
    return 0
  fi
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${t}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user" 2>/dev/null || echo "000")"
  [[ "${code}" == "200" ]]
}

snyk_valid() {
  local t="$1"
  [[ -n "${t}" ]] || return 1
  if [[ "${SKIP_VALIDATION:-0}" == "1" ]]; then
    return 0
  fi
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${t}" \
    -H "Content-Type: application/json" \
    "https://api.snyk.io/v1/user" 2>/dev/null || echo "000")"
  [[ "${code}" == "200" ]]
}

prompt_secret() {
  local label="$1"
  local val
  read -r -s -p "Enter ${label} (input hidden): " val
  echo "" >&2
  echo "${val}"
}

remove_managed_block() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v begin="${MARK_BEGIN}" -v end="${MARK_END}" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "${file}" > "${tmp}" 2>/dev/null || cp "${file}" "${tmp}"
  mv "${tmp}" "${file}"
}

write_managed_block() {
  local file="$1"
  local github="$2"
  local snyk="$3"
  remove_managed_block "${file}"
  {
    echo ""
    echo "${MARK_BEGIN}"
    printf 'export GITHUB_TOKEN=%q\n' "${github}"
    printf 'export SNYK_TOKEN=%q\n' "${snyk}"
    echo "${MARK_END}"
    echo ""
  } >> "${file}"
}

# Resolve current GitHub token from profile (GITHUB_TOKEN or GH_TOKEN)
GITHUB_VAL="$(extract_export_value GITHUB_TOKEN "${PROFILE}" || true)"
if [[ -z "${GITHUB_VAL}" ]]; then
  GITHUB_VAL="$(extract_export_value GH_TOKEN "${PROFILE}" || true)"
fi
SNYK_VAL="$(extract_export_value SNYK_TOKEN "${PROFILE}" || true)"

echo "Profile: ${PROFILE}"
echo ""

need_github=0
if [[ -z "${GITHUB_VAL}" ]]; then
  echo "GITHUB_TOKEN: not set in profile."
  need_github=1
elif github_valid "${GITHUB_VAL}"; then
  echo "GITHUB_TOKEN: present and valid; skipping."
else
  echo "GITHUB_TOKEN: present but invalid or expired; will prompt."
  need_github=1
fi

need_snyk=0
if [[ -z "${SNYK_VAL}" ]]; then
  echo "SNYK_TOKEN: not set in profile."
  need_snyk=1
elif snyk_valid "${SNYK_VAL}"; then
  echo "SNYK_TOKEN: present and valid; skipping."
else
  echo "SNYK_TOKEN: present but invalid or expired; will prompt."
  need_snyk=1
fi

if [[ "${need_github}" -eq 0 && "${need_snyk}" -eq 0 ]]; then
  echo ""
  echo "Nothing to update."
  exit 0
fi

if [[ "${need_github}" -eq 1 ]]; then
  GITHUB_VAL="$(prompt_secret "GITHUB_TOKEN")"
  while [[ -z "${GITHUB_VAL}" ]] || ! github_valid "${GITHUB_VAL}"; do
    echo "Invalid or empty GitHub token. Try again (Ctrl+C to abort)." >&2
    GITHUB_VAL="$(prompt_secret "GITHUB_TOKEN")"
  done
fi

if [[ "${need_snyk}" -eq 1 ]]; then
  SNYK_VAL="$(prompt_secret "SNYK_TOKEN")"
  while [[ -z "${SNYK_VAL}" ]] || ! snyk_valid "${SNYK_VAL}"; do
    echo "Invalid or empty Snyk token. Try again (Ctrl+C to abort)." >&2
    SNYK_VAL="$(prompt_secret "SNYK_TOKEN")"
  done
fi

# GITHUB_VAL / SNYK_VAL already hold skipped (still-valid) or newly prompted values
write_managed_block "${PROFILE}" "${GITHUB_VAL}" "${SNYK_VAL}"

echo ""
echo "Updated ${PROFILE}."
echo "Run: source ${PROFILE}"
echo "Or open a new terminal so other skills can read GITHUB_TOKEN and SNYK_TOKEN."
