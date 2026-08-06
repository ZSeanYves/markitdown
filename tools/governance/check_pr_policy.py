#!/usr/bin/env python3
"""Enforce the repository-side parts of the Phase 0 PR contract."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REQUIRED_HEADINGS = (
    "## Change summary",
    "## Scope",
    "## Risk and ownership",
    "## Contract and compatibility",
    "## Verification",
    "## Checklist",
)
GENERATED_MARKERS = (".mbti", "golden", "snapshot", ".expected.md", ".result.md")
STABLE_API_FILES = {
    "api/pkg.generated.mbti",
    "tools/governance/api-v0.8.mbti",
}


def changed_files(base: str | None, head: str | None) -> list[str]:
    if not base or not head:
        return []
    output = subprocess.check_output(
        ["git", "diff", "--name-only", f"{base}...{head}"], cwd=ROOT, text=True
    )
    return [line for line in output.splitlines() if line]


def validate(body: str, files: list[str]) -> list[str]:
    errors = [f"PR body is missing required section: {heading}" for heading in REQUIRED_HEADINGS if heading not in body]
    generated = [path for path in files if any(marker in path.lower() for marker in GENERATED_MARKERS)]
    if generated:
        marker = "Golden output explanation (required for every golden change):"
        generated_marker = "- Generated artifacts and regeneration command:"
        if marker not in body and generated_marker not in body:
            errors.append("generated/golden files changed without an explanation section")
    if any(path in STABLE_API_FILES for path in files):
        if "Risk: `R3`" not in body:
            errors.append("stable API change must be classified as Risk: `R3`")
        if "docs/rfcs/" not in body and "docs/adr/" not in body:
            errors.append("stable API change must reference a reviewed RFC or ADR")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--body-file", type=Path)
    parser.add_argument("--event-path", type=Path)
    args = parser.parse_args()
    if args.event_path:
        event = json.loads(args.event_path.read_text(encoding="utf-8"))
        pull_request = event.get("pull_request")
        if not pull_request:
            print("PR policy: non-pull-request event; no body contract to enforce")
            return 0
        body = pull_request.get("body") or ""
        base = pull_request.get("base", {}).get("sha")
        head = pull_request.get("head", {}).get("sha") or event.get("after")
        files = changed_files(base, head)
    else:
        body = args.body_file.read_text(encoding="utf-8") if args.body_file else ""
        files = []
    errors = validate(body, files)
    if errors:
        for error in errors:
            print(f"PR policy: {error}", file=sys.stderr)
        return 1
    print("PR policy sections and generated-file explanation pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
