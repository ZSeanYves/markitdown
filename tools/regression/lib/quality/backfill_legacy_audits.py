#!/usr/bin/env python3
"""Backfill machine-readable audits from approved legacy quality evidence.

This tool never downloads evidence and never invents a license payload. A new
audit is written only when an actual LICENSE/COPYING/NOTICE file is available
in the source directory or one of its quality-lab ancestors. Existing audits
are refreshed with every manifest payload covered by that source.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlparse

from intake_lint import audit_for, evidence_ancestors, read_tsv, resolve_payload, source_dir


LICENSE_URLS = {
    "apache_poi_tests": "https://raw.githubusercontent.com/apache/poi/trunk/LICENSE",
    "commonmark_tools_templates": "https://raw.githubusercontent.com/commonmark/commonmark-spec/master/LICENSE",
    "jsonlines_tests": "https://raw.githubusercontent.com/wbolster/jsonlines/master/LICENSE.rst",
    "mdn_content_pages": "https://raw.githubusercontent.com/mdn/content/main/LICENSE.md",
    "openxml_sdk_tests": "https://raw.githubusercontent.com/dotnet/Open-XML-SDK/main/LICENSE",
    "pandas_parser_data": "https://raw.githubusercontent.com/pandas-dev/pandas/main/LICENSE",
    "pandas_repo_docs": "https://raw.githubusercontent.com/pandas-dev/pandas/main/LICENSE",
    "pydantic_repo_toml": "https://raw.githubusercontent.com/pydantic/pydantic/main/LICENSE",
    "toml_test_suite": "https://raw.githubusercontent.com/toml-lang/toml-test/master/LICENSE",
    "yaml_test_suite": "https://raw.githubusercontent.com/yaml/yaml-test-suite/main/License",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def catalog_index(path: Path) -> dict[str, dict[str, str]]:
    _, rows = read_tsv(path)
    result: dict[str, dict[str, str]] = {}
    for row in rows:
        for key in ("id", "source_id", "proposed_source_id"):
            value = row.get(key, "").strip()
            if value:
                result[value] = row
    return result


def nearest_license(directory: Path, lab_root: Path) -> Path | None:
    for current in evidence_ancestors(directory, lab_root):
        candidates = sorted(
            [*current.glob("LICENSE*"), *current.glob("COPYING*"), *current.glob("NOTICE*")]
        )
        if candidates:
            return candidates[0]
    return None


def upstream_license_url(source_url: str, evidence: Path) -> str:
    parsed = urlparse(source_url)
    if parsed.netloc == "github.com":
        parts = [part for part in parsed.path.split("/") if part]
        if len(parts) >= 2:
            upstream_name = "NOTICE" if evidence.name.startswith("NOTICE") else (
                "COPYING" if evidence.name.startswith("COPYING") else "LICENSE"
            )
            return f"https://github.com/{parts[0]}/{parts[1]}/blob/HEAD/{upstream_name}"
    return source_url


def payload_record(lab_root: Path, row: dict[str, str]) -> dict[str, object] | None:
    payload = resolve_payload(lab_root, row.get("path", "").strip())
    if not payload.is_file():
        return None
    return {
        "path": payload.name,
        "payload_sha256": sha256(payload),
        "payload_bytes": payload.stat().st_size,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lab-root", type=Path, default=Path("markitdown-quality-lab"))
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--reviewed-at", default="2026-07-17T00:00:00Z")
    args = parser.parse_args()
    lab_root = args.lab_root.resolve()
    manifest = lab_root / "external_quality/MANIFEST.tsv"
    catalog_path = lab_root / "external_quality/SOURCE_CATALOG.tsv"
    _, rows = read_tsv(manifest)
    catalogs = catalog_index(catalog_path)
    groups: dict[tuple[Path, str], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        payload = resolve_payload(lab_root, row.get("path", "").strip())
        if not payload.is_file():
            continue
        directory = source_dir(lab_root, row.get("local_cache_path", ""), payload)
        groups[(directory.resolve(), row.get("source_id", "").strip())].append(row)

    written = 0
    refreshed = 0
    missing: list[str] = []
    conflicts: list[str] = []
    claimed: dict[Path, str] = {}
    for (directory, source_id), source_rows in sorted(
        groups.items(), key=lambda item: (str(item[0][0]), item[0][1])
    ):
        existing_path = audit_for(directory, lab_root, source_id)
        target = existing_path or directory / "_audit/AUDIT.json"
        prior_source = claimed.get(target)
        if prior_source is not None and prior_source != source_id:
            target = directory / "_audit" / f"{source_id}.json"
        claimed[target] = source_id
        payloads = [record for row in source_rows if (record := payload_record(lab_root, row))]
        payloads = list({record["payload_sha256"]: record for record in payloads}.values())
        payloads.sort(key=lambda record: str(record["path"]))
        if existing_path:
            data = json.loads(existing_path.read_text(encoding="utf-8"))
            if data.get("source_id") != source_id:
                conflicts.append(f"{existing_path}: audit source differs from {source_id}")
                continue
            merged = {item.get("payload_sha256"): item for item in data.get("payloads", [])}
            merged.update({item["payload_sha256"]: item for item in payloads})
            data["payloads"] = sorted(merged.values(), key=lambda item: str(item.get("path", "")))
            if data.get("reviewer") == "local legacy evidence migration":
                data["retrieved_at"] = "unknown"
                data["retrieval_status"] = (
                    "legacy fixture capture predates machine-readable intake audit"
                )
                if source_id in LICENSE_URLS:
                    data["license_url"] = LICENSE_URLS[source_id]
            if args.apply:
                existing_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            refreshed += 1
            continue

        evidence = nearest_license(directory, lab_root)
        if evidence is None:
            missing.append(f"{source_id}\t{directory.relative_to(lab_root)}")
            continue
        catalog = catalogs.get(source_id, {})
        first = source_rows[0]
        source_url = catalog.get("url", "").strip() or first.get("original_url", "").strip()
        license_spdx = first.get("license_status", "").strip() or catalog.get("license_status", "").strip()
        privacy_values = sorted({row.get("privacy", "").strip() for row in source_rows if row.get("privacy", "").strip()})
        first_payload = payloads[0]
        data = {
            "source_id": source_id,
            "retrieval_url": first.get("original_url", "").strip() or source_url,
            "final_url": first.get("original_url", "").strip() or source_url,
            "retrieved_at": "unknown",
            "retrieval_status": "legacy fixture capture predates machine-readable intake audit",
            "source_revision": "legacy-manifest-unpinned",
            "license_spdx": license_spdx,
            "license_url": LICENSE_URLS.get(
                source_id, upstream_license_url(source_url, evidence)
            ),
            "license_text_sha256": sha256(evidence),
            "payload_sha256": first_payload["payload_sha256"],
            "payload_bytes": first_payload["payload_bytes"],
            "redistribution_basis": f"approved legacy manifest; {license_spdx} evidence retained at {evidence.relative_to(lab_root)}",
            "privacy_status": "approved legacy manifest classifications: " + ", ".join(privacy_values),
            "review_status": "approved",
            "reviewer": "local legacy evidence migration",
            "reviewed_at": args.reviewed_at,
            "license_evidence_path": evidence.relative_to(lab_root).as_posix(),
            "payloads": payloads,
        }
        if args.apply:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        written += 1

    print(f"legacy audit backfill: new={written} refreshed={refreshed} missing={len(missing)} conflicts={len(conflicts)} apply={args.apply}")
    for item in missing:
        print("missing-license\t" + item)
    for item in conflicts:
        print("conflict\t" + item)
    return 1 if conflicts else 0


if __name__ == "__main__":
    raise SystemExit(main())
