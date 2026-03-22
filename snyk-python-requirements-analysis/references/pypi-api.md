# PyPI JSON API (used by this skill)

- **Project metadata:** `GET https://pypi.org/pypi/{project}/json`
  - `{project}` should be the **normalized** name (PEP 503); the script uses `packaging.utils.canonicalize_name`.
- **Per-release data:** under `releases`, each version maps to a list of **file** objects. This skill reads **`requires_python`** from those file dicts (falls back to `info.requires_python` when absent).
- **User-Agent:** the script sends a descriptive `User-Agent` (PyPI asks clients not to use generic defaults).
- **Rate limiting:** be reasonable; for huge files batch or cache if you extend the script.

Official overview: [PyPI JSON API](https://docs.pypi.org/api/json/).
