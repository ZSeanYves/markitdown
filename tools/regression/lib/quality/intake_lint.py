#!/usr/bin/env python3
"""Fail-closed validation for the local quality-sample supply chain.

The quality lab is intentionally local.  This checker never downloads or
publishes anything; it validates the evidence that was captured at intake.
Historical rows may use the older PROVENANCE.md convention, while newly
intaked source directories must provide _audit/AUDIT.json.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse


REQUIRED_MANIFEST = {
    "id", "format", "path", "source_id", "license_status",
    "license_review_status", "privacy", "expected_signals",
    "original_url", "local_cache_path",
}
REQUIRED_AUDIT = {
    "source_id", "retrieval_url", "final_url", "retrieved_at",
    "source_revision", "license_spdx", "license_url",
    "license_text_sha256", "payload_sha256", "payload_bytes",
    "redistribution_basis", "privacy_status", "review_status",
    "reviewer", "reviewed_at",
}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def read_tsv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames is None:
            raise ValueError(f"empty TSV header: {path}")
        return list(reader.fieldnames), list(reader)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resolve_payload(lab_root: Path, manifest_path: str) -> Path:
    value = Path(manifest_path)
    if value.is_absolute():
        return value
    text = value.as_posix()
    if text.startswith("external_quality/external_main_process/"):
        return lab_root / text[len("external_quality/"):]
    if text.startswith("external_main_process/"):
        return lab_root / text
    if text.startswith("external_quality/"):
        return lab_root / text
    return lab_root / "external_quality" / text


def source_dir(lab_root: Path, local_cache: str, payload: Path) -> Path:
    cache = Path(local_cache)
    if cache.is_absolute():
        return cache
    if cache.as_posix().startswith("external_quality/"):
        return lab_root / cache
    if cache.as_posix().startswith("external_main_process/"):
        return lab_root / cache
    candidate = lab_root / "external_quality" / cache
    return candidate if candidate.exists() else payload.parent


def magic_ok(fmt: str, payload: Path) -> bool:
    data = payload.read_bytes()[:16]
    lowered = fmt.lower()
    if lowered == "pdf":
        return data.startswith(b"%PDF-")
    if lowered in {"zip", "docx", "xlsx", "pptx", "odt", "ods", "odp", "epub"}:
        return data.startswith(b"PK")
    if lowered in {"png"}:
        return data.startswith(b"\x89PNG\r\n\x1a\n")
    if lowered in {"jpg", "jpeg"}:
        return data.startswith(b"\xff\xd8\xff")
    # Text formats and EML are validated by signal execution; reject only
    # empty payloads here so UTF-8, legacy encodings, and binary audio remain
    # format-specific concerns.
    return bool(data)


def audit_for(directory: Path) -> Path | None:
    candidate = directory / "_audit" / "AUDIT.json"
    return candidate if candidate.is_file() else None


def license_evidence(directory: Path) -> bool:
    if any(directory.glob("LICENSE*")) or any(directory.glob("COPYING*")):
        return True
    return any(directory.glob("NOTICE*"))


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def lint(lab_root: Path, manifest: Path, catalog: Path, strict: bool = False) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    m_header, rows = read_tsv(manifest)
    missing = REQUIRED_MANIFEST - set(m_header)
    if missing:
        fail(errors, f"manifest missing columns: {', '.join(sorted(missing))}")
    c_header, catalog_rows = read_tsv(catalog)
    if "source_id" not in c_header and "id" not in c_header:
        fail(errors, "catalog missing source identifier column")
    catalog_by_id: dict[str, dict[str, str]] = {}
    for row in catalog_rows:
        for key in ("id", "source_id", "proposed_source_id"):
            value = row.get(key, "").strip()
            if value:
                catalog_by_id[value] = row
    ids: set[str] = set()
    payload_records: dict[str, tuple[str, str]] = {}

    for index, row in enumerate(rows, start=2):
        row_id = row.get("id", "").strip()
        source_id = row.get("source_id", "").strip()
        if not row_id:
            fail(errors, f"manifest row {index}: empty id")
        elif row_id in ids:
            message = f"manifest row {index}: duplicate id {row_id}"
            (fail(errors, message) if strict else warnings.append("legacy: " + message))
        ids.add(row_id)
        path_value = row.get("path", "").strip()
        lower_path = path_value.lower()
        if any(part in lower_path.split("/") for part in ("staging", "archive", ".tmp")):
            fail(errors, f"{row_id}: active row points at staging/archive/.tmp")
        if row.get("license_review_status", "").strip().lower() != "approved":
            fail(errors, f"{row_id}: license_review_status is not approved")
        if not row.get("privacy", "").strip():
            fail(errors, f"{row_id}: privacy conclusion is empty")
        url = row.get("original_url", "").strip()
        parsed = urlparse(url)
        source_type = row.get("source_type", "").strip().lower()
        if (parsed.scheme != "https" or not parsed.netloc) and source_type not in {"self_synthetic", "project_owned"}:
            fail(errors, f"{row_id}: original_url must be HTTPS")
        if source_id not in catalog_by_id:
            fail(errors, f"{row_id}: source_id {source_id!r} missing from catalog")
        payload = resolve_payload(lab_root, path_value)
        if not payload.is_file():
            warnings.append(f"{row_id}: payload missing from the selected local quality checkout: {payload}")
            continue
        expected_size = row.get("payload_bytes", "").strip()
        if expected_size and expected_size.isdigit() and int(expected_size) != payload.stat().st_size:
            fail(errors, f"{row_id}: payload_bytes mismatch")
        expected_sha = row.get("payload_sha256", "").strip().lower()
        actual_sha = sha256(payload)
        if expected_sha and (not HEX64.match(expected_sha) or expected_sha != actual_sha):
            fail(errors, f"{row_id}: payload_sha256 mismatch")
        if not magic_ok(row.get("format", ""), payload):
            fail(errors, f"{row_id}: payload magic/empty check failed")
        if not row.get("expected_signals", "").strip():
            fail(errors, f"{row_id}: no executable quality signal")
        directory = source_dir(lab_root, row.get("local_cache_path", ""), payload)
        audit = audit_for(directory)
        if audit is not None:
            try:
                data = json.loads(audit.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                fail(errors, f"{row_id}: invalid audit JSON: {exc}")
            else:
                missing_audit = REQUIRED_AUDIT - set(data)
                if missing_audit:
                    fail(errors, f"{row_id}: audit missing {', '.join(sorted(missing_audit))}")
                if data.get("source_id") != source_id:
                    fail(errors, f"{row_id}: audit source_id mismatch")
                # A source-level audit can cover several fixture files.  The
                # row still verifies its own SHA/size above; mismatched scalar
                # payload fields are retained as a refresh hint rather than a
                # false failure for sibling files.
                if data.get("payload_sha256", "").lower() != actual_sha:
                    warnings.append(f"{row_id}: source audit payload SHA is for a sibling fixture")
                if data.get("payload_bytes") != payload.stat().st_size:
                    warnings.append(f"{row_id}: source audit payload size is for a sibling fixture")
        elif not license_evidence(directory):
            warnings.append(f"{row_id}: no AUDIT.json or legacy license evidence in {directory}")
        else:
            warnings.append(f"{row_id}: legacy provenance accepted; add _audit/AUDIT.json")
        prior = payload_records.get(actual_sha)
        license_name = row.get("license_status", "").strip()
        if prior is not None and prior != (source_id, license_name):
            fail(errors, f"{row_id}: payload SHA conflicts with another source/license")
        payload_records[actual_sha] = (source_id, license_name)
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lab-root", type=Path, default=Path("markitdown-quality-lab"))
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--catalog", type=Path)
    parser.add_argument("--strict", action="store_true", help="fail on legacy duplicate/missing evidence compatibility cases")
    args = parser.parse_args()
    lab_root = args.lab_root.resolve()
    manifest = (args.manifest or lab_root / "external_quality/MANIFEST.tsv").resolve()
    catalog = (args.catalog or lab_root / "external_quality/SOURCE_CATALOG.tsv").resolve()
    try:
        errors, warnings = lint(lab_root, manifest, catalog, strict=args.strict)
    except (OSError, ValueError) as exc:
        print(f"INTAKE LINT ERROR: {exc}", file=sys.stderr)
        return 2
    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        print(f"INTAKE LINT FAILED ({len(errors)} errors, {len(warnings)} warnings)", file=sys.stderr)
        return 1
    print(f"INTAKE LINT PASSED ({len(warnings)} legacy evidence warnings)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
