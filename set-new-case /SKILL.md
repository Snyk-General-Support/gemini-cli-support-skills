---
name: set-new-case
description: Creates a per-case folder under `SNYK_CASES_DIR` (or `~/Desktop/cases`) using the provided case number. Use when starting a new support case so other skills can store artifacts in a consistent location.
---

# Set New Case (Folder Setup)

This skill creates a new case folder under your **cases root**:

- If `SNYK_CASES_DIR` is set: use it.
- Otherwise: use `~/Desktop/cases`.

The folder name is derived from the provided **case number** (unsafe characters are sanitized).

## Inputs

- `CASE_NUMBER`: the case number/key passed by the user (Jira key, numeric id, etc.).

## Workflow

1. Prompt the user for `CASE_NUMBER`.
2. Run the helper script and capture its output as `CASE_DIR`:

```bash
chmod +x "set-new-case /scripts/set_new_case.sh"
export CASE_DIR="$(./set-new-case\ /scripts/set_new_case.sh "${CASE_NUMBER}")"
```

3. Confirm to the user where `CASE_DIR` points (do not print full environment secrets).

## Output / Side effects

- Creates the directory if it doesn’t exist.
- The skill makes `CASE_DIR` available for downstream skills (for example, `broker-log-analysis` writes `"$CASE_DIR/broker_triage.json"`).
