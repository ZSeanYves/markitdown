#!/usr/bin/env python3
"""Execute local Phase 2 contract cases and compare structural signals."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/compatibility/contract-manifest.json"

def structure(markdown: str) -> dict[str, object]:
    lines = markdown.splitlines()
    return {
        "headings": [line.lstrip("#").strip() for line in lines if line.startswith("#")],
        "paragraphs": [line.strip() for line in lines if line.strip() and not line.startswith(("#", "|", "- ", ">", "```", "!["))],
        "tables": [line.strip() for line in lines if line.startswith("|")],
        "links": re.findall(r"\[[^\]]*\]\(([^)]+)\)", markdown),
        "assets": re.findall(r"!\[[^\]]*\]\(([^)]+)\)", markdown),
        "math_markers": [line for line in lines if "math" in line.lower() or "omml" in line.lower()],
        "text": markdown,
    }

def compare_structures(local: dict[str, object], upstream: dict[str, object]) -> list[str]:
    differences = []
    for field in ["headings", "paragraphs", "tables", "links", "assets"]:
        if local.get(field) != upstream.get(field):
            differences.append(field)
    return differences

def run_case(cli: Path, case: dict[str, object], root: Path, mode: str, upstream: Path | None = None, upstream_corpus: Path | None = None, reviewed_differences: dict[str, list[str]] | None = None) -> tuple[bool, str, dict[str, object]]:
    fixture = case.get("input")
    if not fixture:
        return True, "reference-only", {}
    signals = case.get("signals", {})
    input_path = root / str(fixture)
    if upstream_corpus is not None and case.get("upstream_file"):
        candidate = upstream_corpus / str(case["upstream_file"])
        suffix = candidate.suffix.lower().lstrip(".")
        expected = str(case.get("format", "")).lower()
        compatible_suffixes = {expected}
        if expected == "html": compatible_suffixes |= {"htm"}
        if expected == "markdown": compatible_suffixes |= {"md", "markdown"}
        if expected in {"yaml", "toml", "json"}: compatible_suffixes.add("json")
        if candidate.is_file() and suffix in compatible_suffixes:
            input_path = candidate
    with tempfile.TemporaryDirectory(prefix="markitdown-phase2-") as temp:
        output = Path(temp) / "result.md"
        command = [str(cli), mode, str(input_path), str(output)]
        completed = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=90)
        if completed.returncode != 0:
            return False, completed.stderr.strip() or "CLI failed", {}
        text = output.read_text(encoding="utf-8")
        view = structure(text)
        enforce_case_signals = upstream_corpus is None
        for fragment in signals.get("contains", []) if enforce_case_signals else []:
            if fragment not in text:
                return False, f"missing required fragment: {fragment!r}", view
        for fragment in signals.get("not_contains", []) if enforce_case_signals else []:
            if fragment in text:
                return False, f"forbidden fragment present: {fragment!r}", view
        if signals.get("non_empty") and not text.strip():
            return False, "successful conversion produced empty output", view
        if signals.get("diagnostic"):
            debug_output = Path(temp) / "debug.json"
            debug = subprocess.run(
                [str(cli), mode, "--debug", str(input_path), str(debug_output)],
                cwd=root, text=True, capture_output=True, timeout=90,
            )
            if debug.returncode != 0 or signals["diagnostic"] not in debug_output.read_text(encoding="utf-8"):
                return False, f"missing diagnostic: {signals['diagnostic']}", view
        if enforce_case_signals and signals.get("math") == "preserved-text-signature" and not view["math_markers"] and "x \\+ y" not in str(view["text"]):
            return False, "missing preserved math text signature", view
        if upstream is None:
            return True, "pass", view
        reference = Path(temp) / "upstream.md"
        baseline = subprocess.run(
            [str(upstream), str(input_path), "-o", str(reference)],
            cwd=root, text=True, capture_output=True, timeout=90,
        )
        if baseline.returncode != 0:
            return False, baseline.stderr.strip() or "upstream CLI failed", view
        upstream_view = structure(reference.read_text(encoding="utf-8"))
        differences = compare_structures(view, upstream_view)
        expected_differences = None if reviewed_differences is None else reviewed_differences.get(str(case["id"]))
        if upstream_corpus is not None and expected_differences is None:
            return False, "missing reviewed upstream difference fields", view
        if expected_differences is not None and sorted(differences) != sorted(expected_differences):
            return False, "observed structural difference fields differ from reviewed expectation: " + ",".join(differences), view
        if differences and not case.get("classification"):
            return False, "unclassified structural difference: " + ",".join(differences), view
        if differences:
            return True, "classified difference: " + ",".join(differences) + " (" + str(case["classification"]) + ")", view
        return True, "semantic structure match", view

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", type=Path, required=True)
    parser.add_argument("--format")
    parser.add_argument("--upstream", type=Path)
    parser.add_argument("--upstream-corpus", type=Path)
    args = parser.parse_args()
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    failures = 0
    executed = 0
    for case in data["cases"]:
        if case.get("source") != "upstream-compatible-local":
            continue
        if args.format and case["format"] != args.format:
            continue
        modes = case.get("modes", [])
        if args.upstream_corpus is not None and modes:
            modes = modes[:1]
        for mode in modes:
            executed += 1
            ok, detail, view = run_case(args.cli, case, ROOT, str(mode), args.upstream, args.upstream_corpus, data.get("reviewed_upstream_differences"))
            status = "PASS" if ok else "FAIL"
            print(f"{status}\t{case['id']}\t{case['format']}\t{mode}\t{detail}")
            if not ok:
                failures += 1
                print(json.dumps(view, ensure_ascii=True, sort_keys=True), file=sys.stderr)
    print(f"Phase 2 local contract cases: {executed} executed, {failures} failed")
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
