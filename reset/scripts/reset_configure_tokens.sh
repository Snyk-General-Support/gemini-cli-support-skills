#!/usr/bin/env bash
set -euo pipefail

# Must match configure/scripts/configure_tokens.sh
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

remove_managed_block() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v begin="${MARK_BEGIN}" -v end="${MARK_END}" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

PROFILE="$(detect_profile)"

if [[ ! -f "${PROFILE}" ]]; then
  echo "No profile file at ${PROFILE}; nothing to reset."
  exit 0
fi

if ! grep -qxF "${MARK_BEGIN}" "${PROFILE}" 2>/dev/null; then
  echo "No configure-managed token block found in ${PROFILE}."
  echo "Nothing to remove."
  exit 0
fi

if [[ "${RESET_CONFIRM:-}" != "yes" ]]; then
  echo "This will remove the configure skill block (GITHUB_TOKEN / SNYK_TOKEN / SNYK_CASES_DIR exports) from:"
  echo "  ${PROFILE}"
  echo "Your Desktop cases folder (default: ${HOME}/Desktop/cases) is NOT deleted—only profile lines are removed."
  echo ""
  read -r -p "Type RESET to confirm: " reply
  if [[ "${reply}" != "RESET" ]]; then
    echo "Aborted."
    exit 3
  fi
fi

remove_managed_block "${PROFILE}"

echo ""
echo "Removed configure-managed token block from ${PROFILE}."
echo "Cases folder on Desktop was left unchanged (not deleted)."
echo "Open a new terminal or: source ${PROFILE}"
echo "(Current shell may still have old values until you start a new session.)"
