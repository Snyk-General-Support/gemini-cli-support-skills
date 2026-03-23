#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run triage_broker_logs.py without requiring extra Python deps.
# The underlying Python script uses only the standard library.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="${SCRIPT_DIR}/triage_broker_logs.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Missing python3. Install Python 3 to run this triage script." >&2
  exit 2
fi

exec python3 "${PY_SCRIPT}" "$@"

