#!/usr/bin/env python3
"""Validate maintained Markdown and committed benchmark claims."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[2]
ROOT_DOCUMENTS = {
    "AGENTS.md",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "README.md",
    "README.mbt.md",
    "SECURITY.md",
}
REQUIRED_DOCUMENTS = {
    "docs/README.md",
    "docs/api-v0.8.md",
    "docs/capabilities-and-limitations.md",
    "docs/cli-usage-guide.md",
    "docs/compatibility-matrix.md",
    "docs/dependency-register.md",
    "docs/environment-dependencies.md",
    "docs/migration-0.8.md",
    "docs/performance.md",
    "docs/project-maintenance-plan.md",
}
RETIRED_DOCUMENTS = {"docs/migration-0.7.md"}
CURRENT_NARRATIVES = {
    "README.md",
    "README.mbt.md",
    "bench/README.md",
    "CHANGELOG.md",
    "docs/performance.md",
}
LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


def tracked_markdown(root: Path = ROOT) -> list[Path]:
    output = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.md"],
        cwd=root,
        text=True,
    )
    return sorted({root / line for line in output.splitlines() if line})


def maintained_markdown(root: Path = ROOT) -> list[Path]:
    result = []
    for path in tracked_markdown(root):
        if not path.exists():
            continue
        relative = path.relative_to(root)
        if (
            str(relative) in ROOT_DOCUMENTS
            or relative.parts[0] == "docs"
            or path.name in {"README.md", "README.mbt.md"}
        ):
            result.append(path)
    return result


def local_link_target(raw_target: str) -> str | None:
    target = raw_target.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    else:
        target = target.split(maxsplit=1)[0]
    if not target or target.startswith(("#", "/")):
        return None
    if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.IGNORECASE):
        return None
    return unquote(target.split("#", 1)[0].split("?", 1)[0])


def link_errors(root: Path = ROOT) -> list[str]:
    errors = []
    for path in maintained_markdown(root):
        text = path.read_text(encoding="utf-8")
        for raw_target in LINK_RE.findall(text):
            target = local_link_target(raw_target)
            if target is None:
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                errors.append(
                    f"broken local link in {path.relative_to(root)}: {raw_target}"
                )
    return errors


def benchmark_claim_errors(root: Path = ROOT) -> list[str]:
    errors = []
    performance = (root / "docs/performance.md").read_text(encoding="utf-8")
    evidence_manifest = (
        root / "bench/results/2026-08-07-macos-arm64/README.md"
    ).read_text(encoding="utf-8")
    summaries = (
        root / "bench/results/2026-08-07-macos-arm64/external-summary.json",
        root / "bench/results/2026-08-07-macos-arm64/self-summary.json",
    )
    for path in summaries:
        if not path.exists():
            errors.append(f"missing committed benchmark summary: {path.relative_to(root)}")
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest not in evidence_manifest:
            errors.append(
                f"benchmark evidence manifest omits SHA-256 for: {path.relative_to(root)}"
            )
        summary = json.loads(path.read_text(encoding="utf-8"))
        if summary.get("trust_status") != "trusted":
            errors.append(f"benchmark summary is not trusted: {path.relative_to(root)}")
        if summary.get("gate_summary", {}).get("status") != "ok":
            errors.append(f"benchmark gate is not ok: {path.relative_to(root)}")
        contract = summary.get("binary_only_contract", {})
        if not contract.get("runner_release_ok") or not contract.get("cli_release_ok"):
            errors.append(f"benchmark is not release-binary-only: {path.relative_to(root)}")
        run_id = summary.get("run_id", "")
        if not run_id or run_id not in performance:
            errors.append(f"performance document does not cite run: {run_id!r}")
        for tool in summary.get("tools", []):
            milliseconds = f"{int(tool['median_wall_us']) / 1000:.3f} ms"
            if milliseconds not in performance:
                errors.append(
                    f"performance document omits {tool['tool']} median {milliseconds}"
                )
    return errors


def verify(root: Path = ROOT) -> list[str]:
    errors = []
    for relative in sorted(REQUIRED_DOCUMENTS):
        if not (root / relative).is_file():
            errors.append(f"required document is missing: {relative}")
    for relative in sorted(RETIRED_DOCUMENTS):
        if (root / relative).exists():
            errors.append(f"retired document reappeared: {relative}")
    if (root / "README.md").read_bytes() != (root / "README.mbt.md").read_bytes():
        errors.append("README.md and README.mbt.md must be byte-identical")
    for relative in sorted(CURRENT_NARRATIVES):
        text = (root / relative).read_text(encoding="utf-8")
        if "0.1.6" in text:
            errors.append(f"stale MarkItDown 0.1.6 claim in {relative}")
        if "bench/runner" in text or "build/bench/runner" in text:
            errors.append(f"retired benchmark runner path in {relative}")
    errors.extend(link_errors(root))
    errors.extend(benchmark_claim_errors(root))
    return errors


def main() -> int:
    errors = verify()
    if errors:
        for error in errors:
            print(f"documentation: {error}", file=sys.stderr)
        return 1
    print("Documentation links, lifecycle and benchmark claims pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
