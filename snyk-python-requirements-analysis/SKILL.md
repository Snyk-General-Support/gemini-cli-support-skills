---
name: snyk-python-requirements-analysis
description: Analyzes a requirements.txt using the PyPI JSON API to show each dependency’s resolved version and requires_python, recommends a minimum Python version, and optionally verifies a user-supplied Python version. Use when the user asks for Python version compatibility from requirements.txt or PyPI metadata.
---

# Python requirements → minimum Python (PyPI)

Given a **`requirements.txt`**, query **pypi.org** (JSON API) for each **direct** dependency, resolve a **matching release** (latest that satisfies the specifier), read **`requires_python`** from PyPI, and:

1. Show a **table**: dependency → resolved version → `requires_python`.
2. Suggest a **recommended minimum Python** that satisfies the combined constraints.
3. If the user names a Python version to **validate**, run the same analysis and report **whether that version is compatible**.

## Limits (important)

- Analysis is for **declared lines in the file** only (plus PyPI metadata for those packages). It does **not** run a full **pip resolver** or walk **transitive** dependencies. For a complete install graph, use **`pip-compile`**, **Poetry**, **uv**, etc., then scan that output with this skill or Snyk.
- **`-r` / nested requirements files** are not expanded in v1 of the script.

## Workflow

1. **Prompt** for the path to **`requirements.txt`** (or accept it from the user message).
2. Ensure script dependencies:  
   `python3 -m pip install -r snyk-python-requirements-analysis/scripts/requirements.txt`
3. **Run the analyzer** (Markdown table + recommendation):

   ```bash
   ./snyk-python-requirements-analysis/scripts/analyze_requirements.py /path/to/requirements.txt
   ```

4. **Optional — confirm a Python version** (e.g. user asks “is 3.10 ok?”):

   ```bash
   ./snyk-python-requirements-analysis/scripts/analyze_requirements.py /path/to/requirements.txt --check-python 3.10
   ```

5. **Optional — JSON** for tooling:

   ```bash
   ./snyk-python-requirements-analysis/scripts/analyze_requirements.py /path/to/requirements.txt --json
   ./snyk-python-requirements-analysis/scripts/analyze_requirements.py /path/to/requirements.txt --check-python 3.11 --json
   ```

6. Summarize in natural language: table highlights, **recommended** Python, and **pass/fail** for `--check-python` if used.

## Scripts

| Script | Role |
|--------|------|
| `scripts/analyze_requirements.py` | PyPI fetch, table, min Python, `--check-python` |
| `scripts/requirements.txt` | Runtime dependency: `packaging` |

## References

- PyPI JSON API: [references/pypi-api.md](references/pypi-api.md)

## Agent behavior

- Do not assume the path to `requirements.txt`; **ask** if missing.
- Treat PyPI as **source of truth** for `requires_python` on the **chosen** release (not the user’s local venv).
- If a package is missing on PyPI or the specifier cannot be satisfied, say so clearly in the table (Notes column).
- When the user supplies a Python version to verify, use **`--check-python`** and explain **pass vs fail** in plain language.
