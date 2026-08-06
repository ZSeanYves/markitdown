#!/usr/bin/env python3
"""Enforce the Phase 1 stable API and dependency boundaries."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BOUNDARY_FILE = ROOT / "tools/governance/phase1-boundary.json"
ALLOWED_API_IMPORTS = {
    "moonbitlang/core/debug",
    "moonbitlang/core/encoding/utf8",
    "moonbitlang/x/fs",
    "ZSeanYves/markitdown/convert",
    "ZSeanYves/markitdown/core",
    "ZSeanYves/markitdown/input",
    "ZSeanYves/markitdown/parser",
    "ZSeanYves/markitdown/product",
    "ZSeanYves/markitdown/rag",
}
FORBIDDEN_STABLE_NAMES = (
    "ZSeanYves/markitdown/convert",
    "ZSeanYves/markitdown/core",
    "ZSeanYves/markitdown/format_readers",
    "ZSeanYves/markitdown/formats",
    "ZSeanYves/markitdown/input",
    "ZSeanYves/markitdown/parser",
    "ZSeanYves/markitdown/pipeline",
    "ZSeanYves/markitdown/product",
    "ZSeanYves/markitdown/rag",
    "ZSeanYves/markitdown/render",
    "ZSeanYves/markitdown/runtime",
)
IGNORED_PARTS = {
    ".git",
    ".mooncakes",
    ".tmp",
    "_build",
    "env",
    "markitdown-quality-lab",
}


def read_boundary(root: Path = ROOT) -> dict:
    return json.loads((root / "tools/governance/phase1-boundary.json").read_text(encoding="utf-8"))


def quoted_imports(text: str) -> set[str]:
    return {
        value
        for value in re.findall(r'"([A-Za-z0-9_./@-]+)"', text)
        if "/" in value
    }


def api_import_errors(imports: set[str]) -> list[str]:
    return [f"api imports unapproved package: {name}" for name in sorted(imports - ALLOWED_API_IMPORTS)]


def api_surface_errors(current: str, golden: str) -> list[str]:
    errors: list[str] = []
    if current != golden:
        errors.append("api interface differs from the reviewed 0.8 golden; regenerate and review the API RFC")
    for name in FORBIDDEN_STABLE_NAMES:
        if name in current:
            errors.append(f"stable api leaks internal package type: {name}")
    return errors


def moonbit_sources(root: Path) -> list[Path]:
    return [
        path
        for path in root.rglob("*.mbt")
        if not any(part in IGNORED_PARTS for part in path.relative_to(root).parts)
    ]


def public_all_count(root: Path) -> int:
    pattern = re.compile(r"pub\(all\)")
    return sum(len(pattern.findall(path.read_text(encoding="utf-8"))) for path in moonbit_sources(root))


def direct_dependencies(text: str) -> set[str]:
    match = re.search(r"\bimport\s*\{(.*?)\}", text, re.DOTALL)
    return set(re.findall(r'"([^\"]+@[^\"]+)"', match.group(1))) if match else set()


def top_level_deep_import_counts(root: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    pattern = re.compile(r'"(ZSeanYves/markitdown/(?:formats|format_readers)/[^\"]+)"')
    for path in root.rglob("moon.pkg"):
        relative = path.relative_to(root)
        if any(part in IGNORED_PARTS for part in relative.parts):
            continue
        if relative.parts[0] in {"formats", "format_readers", "internal"}:
            continue
        imports = set(pattern.findall(path.read_text(encoding="utf-8")))
        if imports:
            counts[str(relative)] = len(imports)
    return counts


def verify(root: Path = ROOT) -> list[str]:
    boundary = read_boundary(root)
    errors: list[str] = []
    interface_path = root / boundary["stable_api"]
    golden_path = root / boundary["api_golden"]
    if not interface_path.exists() or not golden_path.exists():
        return ["stable API interface or golden is missing; run `moon info api`"]
    errors.extend(
        api_surface_errors(
            interface_path.read_text(encoding="utf-8"),
            golden_path.read_text(encoding="utf-8"),
        )
    )
    errors.extend(api_import_errors(quoted_imports((root / "api/moon.pkg").read_text(encoding="utf-8"))))
    api_mutable_records = sum(
        len(re.findall(r"pub\(all\)\s+(?:struct|type)", path.read_text(encoding="utf-8")))
        for path in (root / "api").glob("*.mbt")
    )
    if api_mutable_records:
        errors.append("stable api records must be readonly or abstract, not pub(all)")
    observed_public_all = public_all_count(root)
    if observed_public_all > boundary["legacy_pub_all_max"]:
        errors.append(
            f"legacy pub(all) budget grew: maximum {boundary['legacy_pub_all_max']}, observed {observed_public_all}"
        )
    expected_dependencies = set(boundary["direct_dependencies"])
    observed_dependencies = direct_dependencies((root / "moon.mod").read_text(encoding="utf-8"))
    if observed_dependencies != expected_dependencies:
        errors.append(
            "direct dependency set changed: expected "
            + repr(sorted(expected_dependencies))
            + ", observed "
            + repr(sorted(observed_dependencies))
        )
    deep_limits = boundary["legacy_top_level_deep_import_limits"]
    for path, count in top_level_deep_import_counts(root).items():
        limit = deep_limits.get(path, 0)
        if count > limit:
            errors.append(
                f"top-level package gained deep format imports: {path} has {count}, limit {limit}"
            )
    return errors


def main() -> int:
    errors = verify()
    if errors:
        for error in errors:
            print(f"architecture policy: {error}", file=sys.stderr)
        return 1
    print("Phase 1 API, dependency, import and visibility boundaries pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
