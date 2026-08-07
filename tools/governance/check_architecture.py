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
    "ZSeanYves/markitdown/internal/parser",
    "ZSeanYves/markitdown/product",
    "ZSeanYves/markitdown/rag",
}
FORBIDDEN_STABLE_NAMES = (
    "ZSeanYves/markitdown/convert",
    "ZSeanYves/markitdown/core",
    "ZSeanYves/markitdown/internal/readers",
    "ZSeanYves/markitdown/formats",
    "ZSeanYves/markitdown/input",
    "ZSeanYves/markitdown/internal/parser",
    "ZSeanYves/markitdown/internal/pipeline",
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
    source_root = root / "src"
    return [
        path
        for path in source_root.rglob("*.mbt")
        if not any(part in IGNORED_PARTS for part in path.relative_to(source_root).parts)
    ]


def public_all_count(root: Path) -> int:
    pattern = re.compile(r"pub\(all\)")
    return sum(len(pattern.findall(path.read_text(encoding="utf-8"))) for path in moonbit_sources(root))


def public_all_mutable_record_count(root: Path) -> int:
    pattern = re.compile(r"pub\(all\)\s+struct\b")
    return sum(len(pattern.findall(path.read_text(encoding="utf-8"))) for path in moonbit_sources(root))


def moon_package_count(root: Path) -> int:
    source_root = root / "src"
    return sum(
        1
        for path in source_root.rglob("moon.pkg")
        if not any(part in IGNORED_PARTS for part in path.relative_to(source_root).parts)
    )


def moon_packages_outside_source(root: Path) -> list[str]:
    source_root = root / "src"
    return sorted(
        str(path.relative_to(root))
        for path in root.rglob("moon.pkg")
        if not path.is_relative_to(source_root)
        and not any(part in IGNORED_PARTS for part in path.relative_to(root).parts)
    )


def direct_dependencies(text: str) -> set[str]:
    match = re.search(r"\bimport\s*\{(.*?)\}", text, re.DOTALL)
    return set(re.findall(r'"([^\"]+@[^\"]+)"', match.group(1))) if match else set()


def top_level_deep_import_counts(root: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    pattern = re.compile(r'"(ZSeanYves/markitdown/(?:formats|internal/readers)/[^\"]+)"')
    source_root = root / "src"
    for path in source_root.rglob("moon.pkg"):
        relative = path.relative_to(source_root)
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
        return [
            "stable API interface or golden is missing; run "
            "`moon info --package ZSeanYves/markitdown/api`"
        ]
    errors.extend(
        api_surface_errors(
            interface_path.read_text(encoding="utf-8"),
            golden_path.read_text(encoding="utf-8"),
        )
    )
    source_root = root / boundary["source_root"]
    module_text = (root / "moon.mod").read_text(encoding="utf-8")
    if not re.search(r'^source\s*=\s*"src"\s*$', module_text, re.MULTILINE):
        errors.append('moon.mod must declare source = "src"')
    outside_packages = moon_packages_outside_source(root)
    if outside_packages:
        errors.append("MoonBit packages must live under src/: " + repr(outside_packages))
    errors.extend(api_import_errors(quoted_imports((source_root / "api/moon.pkg").read_text(encoding="utf-8"))))
    api_mutable_records = sum(
        len(re.findall(r"pub\(all\)\s+(?:struct|type)", path.read_text(encoding="utf-8")))
        for path in (source_root / "api").glob("*.mbt")
    )
    if api_mutable_records:
        errors.append("stable api records must be readonly or abstract, not pub(all)")
    observed_public_all = public_all_count(root)
    if observed_public_all > boundary["legacy_pub_all_max"]:
        errors.append(
            f"legacy pub(all) budget grew: maximum {boundary['legacy_pub_all_max']}, observed {observed_public_all}"
        )
    observed_mutable_records = public_all_mutable_record_count(root)
    if observed_mutable_records > boundary["legacy_pub_all_mutable_record_max"]:
        errors.append(
            "mutable pub(all) record budget grew: maximum "
            f"{boundary['legacy_pub_all_mutable_record_max']}, observed {observed_mutable_records}"
        )
    observed_packages = moon_package_count(root)
    if observed_packages > boundary["package_count_max"]:
        errors.append(
            f"package count grew: maximum {boundary['package_count_max']}, observed {observed_packages}"
        )
    for retired_root in boundary["retired_public_roots"]:
        if (source_root / retired_root / "moon.pkg").exists() or any((source_root / retired_root).glob("**/moon.pkg")):
            errors.append(f"retired public package root reappeared: {retired_root}")
    expected_dependencies = set(boundary["direct_dependencies"])
    observed_dependencies = direct_dependencies(module_text)
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
