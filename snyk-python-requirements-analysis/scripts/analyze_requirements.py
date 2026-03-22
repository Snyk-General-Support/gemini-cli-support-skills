#!/usr/bin/env python3
"""
Resolve requirements.txt against PyPI and report each dependency's resolved version
and requires_python, then recommend a minimum Python version.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Iterable, Optional

try:
    from packaging.requirements import Requirement
    from packaging.specifiers import SpecifierSet
    from packaging.utils import canonicalize_name
    from packaging.version import InvalidVersion, Version, parse as parse_version
except ImportError:
    print(
        "Missing dependency: install with\n"
        "  python3 -m pip install -r snyk-python-requirements-analysis/scripts/requirements.txt",
        file=sys.stderr,
    )
    sys.exit(2)


PYPI_JSON = "https://pypi.org/pypi/{}/json"
USER_AGENT = "snyk-python-requirements-analysis/1.0 (skill; +https://pypi.org/pypi)"


@dataclass
class Row:
    name: str
    requested: str
    resolved_version: str
    requires_python: str
    note: str = ""


def fetch_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def parse_requirements_lines(path: str) -> list[str]:
    lines: list[str] = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("-r ") or line.startswith("--requirement"):
                continue  # nested requirements not supported in v1
            lines.append(line)
    return lines


def requires_python_from_release(files: list[dict]) -> Optional[str]:
    for item in files:
        rp = item.get("requires_python")
        if rp:
            return str(rp).strip()
    return None


def candidate_versions(releases: dict) -> list[Version]:
    out: list[Version] = []
    for ver_str in releases:
        try:
            out.append(parse_version(ver_str))
        except InvalidVersion:
            continue
    out.sort(reverse=True)
    return out


def pick_resolved_version(
    project: str, spec: SpecifierSet, releases: dict
) -> tuple[Optional[str], Optional[list], str]:
    """Return (version_string, release_file_list, note)."""
    versions = candidate_versions(releases)
    if not versions:
        return None, None, "no releases on PyPI"
    for v in versions:
        if spec.contains(v):
            key = next(
                (k for k in releases if _version_key_eq(k, v)),
                None,
            )
            if key is None:
                continue
            files = releases[key]
            return str(v), files, ""
    return None, None, "no release matches specifier"


def _version_key_eq(key: str, v: Version) -> bool:
    try:
        return parse_version(key) == v
    except InvalidVersion:
        return False


def specifier_from_requires_python(text: Optional[str]) -> SpecifierSet:
    if not text or not str(text).strip():
        return SpecifierSet()
    return SpecifierSet(str(text).strip())


def python_satisfies_all(version: Version, specifiers: Iterable[SpecifierSet]) -> bool:
    for s in specifiers:
        if s and not s.contains(version):
            return False
    return True


def find_min_python(specifiers: list[SpecifierSet]) -> Optional[Version]:
    """Find lowest 3.x.y that satisfies all requires_python specifiers."""
    # Search 3.7.0 .. 3.15.0 minor by minor (good enough for recommendation)
    for minor in range(7, 16):
        v = Version(f"3.{minor}.0")
        if python_satisfies_all(v, specifiers):
            return v
    return None


def analyze(requirements_path: str) -> tuple[list[Row], list[SpecifierSet]]:
    rows: list[Row] = []
    combined_specs: list[SpecifierSet] = []

    for line in parse_requirements_lines(requirements_path):
        try:
            req = Requirement(line)
        except Exception as e:
            rows.append(
                Row(
                    name="?",
                    requested=line,
                    resolved_version="—",
                    requires_python="—",
                    note=f"parse error: {e}",
                )
            )
            continue

        if req.marker is not None and not req.marker.evaluate():
            rows.append(
                Row(
                    name=str(req.name),
                    requested=line,
                    resolved_version="—",
                    requires_python="—",
                    note="skipped (marker false for default env)",
                )
            )
            continue

        name = canonicalize_name(req.name)
        url = PYPI_JSON.format(name)
        try:
            data = fetch_json(url)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                rows.append(
                    Row(
                        name=name,
                        requested=line,
                        resolved_version="—",
                        requires_python="—",
                        note="not found on PyPI",
                    )
                )
            else:
                rows.append(
                    Row(
                        name=name,
                        requested=line,
                        resolved_version="—",
                        requires_python="—",
                        note=f"PyPI HTTP {e.code}",
                    )
                )
            continue
        except Exception as e:
            rows.append(
                Row(
                    name=name,
                    requested=line,
                    resolved_version="—",
                    requires_python="—",
                    note=f"fetch error: {e}",
                )
            )
            continue

        releases = data.get("releases") or {}
        ver_str, files, note = pick_resolved_version(name, req.specifier, releases)
        if ver_str is None:
            rows.append(
                Row(
                    name=name,
                    requested=line,
                    resolved_version="—",
                    requires_python="—",
                    note=note or "unresolved",
                )
            )
            continue

        rp = requires_python_from_release(files or [])
        if not rp:
            rp = (data.get("info") or {}).get("requires_python") or ""
        rp_display = rp.strip() if rp else "(not specified; assume any)"
        spec = specifier_from_requires_python(rp if rp else None)
        combined_specs.append(spec)

        rows.append(
            Row(
                name=name,
                requested=line,
                resolved_version=ver_str,
                requires_python=rp_display,
                note=note,
            )
        )

    return rows, combined_specs


def print_markdown_table(rows: list[Row]) -> None:
    print("| Dependency | Requested | Resolved version | `requires_python` (PyPI) | Notes |")
    print("|------------|-----------|------------------|--------------------------|-------|")
    for r in rows:
        print(
            f"| {r.name} | `{r.requested}` | {r.resolved_version} | {r.requires_python} | {r.note} |"
        )


def parse_check_py(s: str) -> Version:
    s = s.strip()
    m = re.match(r"^(\d+)\.(\d+)(?:\.(\d+))?$", s)
    if not m:
        raise argparse.ArgumentTypeError(f"expected e.g. 3.11 or 3.11.0, got {s!r}")
    major, minor, patch = m.group(1), m.group(2), m.group(3) or "0"
    return Version(f"{major}.{minor}.{patch}")


def main() -> int:
    p = argparse.ArgumentParser(
        description="Analyze requirements.txt using PyPI JSON API."
    )
    p.add_argument(
        "requirements_file",
        help="Path to requirements.txt",
    )
    p.add_argument(
        "--check-python",
        type=parse_check_py,
        metavar="X.Y[.Z]",
        help="After analysis, verify this Python version satisfies all requires_python",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON instead of Markdown",
    )
    args = p.parse_args()

    rows, combined = analyze(args.requirements_file)
    min_py = find_min_python(combined)

    if args.json:
        out = {
            "rows": [
                {
                    "name": r.name,
                    "requested": r.requested,
                    "resolved_version": r.resolved_version,
                    "requires_python": r.requires_python,
                    "note": r.note,
                }
                for r in rows
            ],
            "recommended_minimum_python": str(min_py) if min_py else None,
        }
        if args.check_python is not None:
            out["check_python"] = str(args.check_python)
            out["check_python_ok"] = python_satisfies_all(args.check_python, combined)
        print(json.dumps(out, indent=2))
        return 0

    print_markdown_table(rows)
    print()
    if min_py:
        print(
            f"**Recommended minimum Python (from combined `requires_python`):** `{min_py}` "
            f"(first 3.x.0 in scan range that satisfies all constraints)."
        )
    else:
        print(
            "**Recommended minimum Python:** could not find a 3.7–3.15 version satisfying "
            "all constraints — check for conflicts or unsupported packages."
        )

    if args.check_python is not None:
        ok = python_satisfies_all(args.check_python, combined)
        print()
        if ok:
            print(
                f"**Check:** Python `{args.check_python}` **satisfies** all collected "
                "`requires_python` constraints (for resolved versions)."
            )
        else:
            print(
                f"**Check:** Python `{args.check_python}` **does not satisfy** at least one "
                "`requires_python` constraint."
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
