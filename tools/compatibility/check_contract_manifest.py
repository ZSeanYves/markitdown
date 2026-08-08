#!/usr/bin/env python3
"""Validate the reviewed Phase 2 contract corpus and coverage matrix."""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/compatibility/contract-manifest.json"
CATEGORIES = ROOT / "tools/compatibility/difference-categories.json"
REQUIRED_FORMATS = {"docx","xlsx","pptx","pdf","html","csv","json","xml","ipynb","zip","epub"}
REQUIRED_INPUT_KINDS = {"path","bytes","reader"}
REQUIRED_HINTS = {"none","mime","extension"}
ALLOWED_SOURCE = {"upstream-compatible-local","upstream-reference-only"}

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def validate(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    try:
        data = json.loads((root / MANIFEST.relative_to(ROOT)).read_text(encoding="utf-8"))
        cats = json.loads((root / CATEGORIES.relative_to(ROOT)).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read Phase 2 manifest: {exc}"]
    if data.get("schema_version") != 1 or cats.get("schema_version") != 1:
        errors.append("Phase 2 manifest and category schema_version must be 1")
    if not data.get("tiers", {}).get("A"):
        errors.append("Tier A must contain at least one format")
    upstream = data.get("upstream", {})
    if upstream.get("tag") != "v0.1.7" or upstream.get("commit") != "fd239d5d2be43d9b68329730206b9312c7d5a388":
        errors.append("upstream reference must remain MarkItDown v0.1.7 at the reviewed commit")
    allowed_categories = set(data.get("comparison", {}).get("allowed_categories", []))
    defined_categories = set(cats.get("categories", {}))
    if allowed_categories != defined_categories:
        errors.append("comparison categories and difference-categories.json disagree")
    cases = data.get("cases", [])
    reviewed = data.get("reviewed_upstream_differences", {})
    ids: set[str] = set()
    seen_formats: set[str] = set()
    for case in cases:
        case_id = case.get("id")
        if not case_id or case_id in ids:
            errors.append(f"duplicate or missing case id: {case_id!r}")
        ids.add(case_id)
        fmt = case.get("format")
        seen_formats.add(fmt)
        if case.get("source") not in ALLOWED_SOURCE:
            errors.append(f"{case_id}: invalid source classification")
        if not case.get("upstream_file"):
            errors.append(f"{case_id}: upstream_file is required")
        if case.get("classification") not in allowed_categories:
            errors.append(f"{case_id}: missing or unknown difference classification")
        signals = case.get("signals")
        if not isinstance(signals, dict) or not signals:
            errors.append(f"{case_id}: reviewed signals are required")
        if case.get("format") == "docx" and signals.get("math") != "preserved-text-signature":
            errors.append(f"{case_id}: DOCX equation case must declare math preservation signal")
        if case.get("format") == "pptx" and "chart" in case.get("comparison_fields", []) and case.get("id") != "pptx-svg-fallback":
            if not signals.get("contains"):
                errors.append(f"{case_id}: PPTX chart case must declare structural content signals")
        if case.get("source") == "upstream-compatible-local":
            fixture = case.get("input")
            if not fixture or not (root / fixture).is_file():
                errors.append(f"{case_id}: local fixture is missing: {fixture}")
            else:
                expected_hash = case.get("fixture_sha256")
                actual_hash = sha256(root / fixture)
                if not isinstance(expected_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
                    errors.append(f"{case_id}: fixture_sha256 must be a lowercase SHA-256")
                elif expected_hash != actual_hash:
                    errors.append(
                        f"{case_id}: fixture hash drifted (manifest={expected_hash}, actual={actual_hash})"
                    )
            if not REQUIRED_INPUT_KINDS.issubset(set(case.get("input_kinds", []))):
                errors.append(f"{case_id}: path/bytes/reader coverage is incomplete")
            if not REQUIRED_HINTS.issubset(set(case.get("hints", []))):
                errors.append(f"{case_id}: none/mime/extension hint coverage is incomplete")
            if not case.get("modes"):
                errors.append(f"{case_id}: at least one executable mode is required")
    missing = REQUIRED_FORMATS - seen_formats
    if missing:
        errors.append("Tier A formats missing from Phase 2 manifest: " + ", ".join(sorted(missing)))
    for tier, formats in data.get("tiers", {}).items():
        if tier not in {"A","B","C"} or not isinstance(formats, list):
            errors.append(f"invalid tier declaration: {tier!r}")
    for tier, formats in data.get("tiers", {}).items():
        for fmt in formats:
            if not any(case.get("format") == fmt and case.get("tier") == tier for case in cases):
                errors.append(f"tier format has no enrolled case: {tier}/{fmt}")
    if not data.get("comparison", {}).get("unclassified_difference_is_failure"):
        errors.append("unclassified differences must be a blocking failure")
    executable_ids = {case.get("id") for case in cases if case.get("source") == "upstream-compatible-local"}
    if set(reviewed) != executable_ids:
        errors.append("reviewed upstream difference fields must exactly cover executable cases")
    allowed_fields = {"headings", "paragraphs", "tables", "links", "assets"}
    for case_id, fields in reviewed.items():
        if not isinstance(fields, list) or len(fields) != len(set(fields)) or not set(fields).issubset(allowed_fields):
            errors.append(f"{case_id}: reviewed upstream difference fields are invalid")
    return errors

def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"Phase 2 contract manifest: {error}", file=sys.stderr)
        return 1
    print("Phase 2 contract manifest, coverage dimensions and difference taxonomy pass")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
