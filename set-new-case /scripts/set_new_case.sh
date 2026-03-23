#!/usr/bin/env bash
set -euo pipefail

CASE_NUMBER="${1:-}"
if [[ -z "${CASE_NUMBER}" ]]; then
  echo "Usage: set_new_case.sh <case_number>" >&2
  exit 2
fi

CASES_ROOT="${SNYK_CASES_DIR:-${CASES_ROOT:-${HOME}/Desktop/cases}}"
mkdir -p "${CASES_ROOT}"

# Folder name should be stable and safe; case keys sometimes include characters like '/'.
case_name="$(echo "${CASE_NUMBER}" | tr ' /' '__')"
case_name="$(echo "${case_name}" | tr -cd 'A-Za-z0-9._-')"
if [[ -z "${case_name}" ]]; then
  echo "Case number sanitized to empty; original: ${CASE_NUMBER}" >&2
  exit 2
fi

CASE_DIR="${CASES_ROOT}/${case_name}"
mkdir -p "${CASE_DIR}"

echo "${CASE_DIR}"

