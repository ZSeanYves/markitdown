#!/usr/bin/env python3
"""Validate showcase bytes, conversion output, and quality-lab evidence."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import unquote


REPO = Path(__file__).resolve().parents[2]
ROOT = Path(__file__).resolve().parent
LAB = REPO / "markitdown-quality-lab"
FORMATS = {
    "txt", "csv", "tsv", "srt", "vtt", "json", "jsonl", "ndjson",
    "yaml", "toml", "xml", "html", "markdown", "ipynb", "eml", "tex",
    "rst", "asciidoc", "zip", "epub", "docx", "xlsx", "pptx", "odt",
    "ods", "odp", "pdf",
}


def tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def safe(value: str) -> bool:
    path = Path(value)
    return bool(value) and not path.is_absolute() and ".." not in path.parts


def image_magic_matches(path: Path) -> bool:
    data = path.read_bytes()[:32]
    suffix = path.suffix.lower()
    if suffix == ".png":
        return data.startswith(b"\x89PNG\r\n\x1a\n")
    if suffix in {".jpg", ".jpeg"}:
        return data.startswith(b"\xff\xd8\xff")
    if suffix == ".gif":
        return data.startswith((b"GIF87a", b"GIF89a"))
    if suffix == ".webp":
        return data.startswith(b"RIFF") and data[8:12] == b"WEBP"
    if suffix in {".tif", ".tiff"}:
        return data.startswith((b"II*\x00", b"MM\x00*"))
    if suffix in {".jp2", ".jpx"}:
        return data.startswith(b"\x00\x00\x00\x0cjP  \r\n\x87\n")
    if suffix in {".jb2", ".jbig2"}:
        return data.startswith(b"\x97JB2\r\n\x1a\n")
    if suffix == ".svg":
        return b"<svg" in data.lower()
    return suffix != ".bin"


def showcase(errors: list[str]) -> None:
    manifest = tsv(ROOT / "MANIFEST.tsv")
    result_manifest = {row["format"]: row for row in tsv(ROOT / "RESULTS.tsv")}
    seen: set[str] = set()
    listed: set[str] = set()
    total = 0
    for row in manifest:
        fmt, rel = row["format"], row["path"]
        label = f"showcase:{fmt}"
        if fmt in seen:
            errors.append(f"{label}: duplicate format")
        seen.add(fmt)
        listed.add(rel)
        path = ROOT / rel
        if not safe(rel) or not path.is_file():
            errors.append(f"{label}: missing or unsafe path {rel!r}")
            continue
        size = path.stat().st_size
        total += size
        if str(size) != row["bytes"] or digest(path) != row["sha256"]:
            errors.append(f"{label}: size or SHA-256 mismatch")
        if size > 3 * 1024 * 1024:
            errors.append(f"{label}: exceeds 3 MiB per-file budget")
        if not row["source_url"].startswith("https://"):
            errors.append(f"{label}: source is not an HTTPS URL")
        for item in row["license_file"].split(";"):
            if not safe(item) or not (ROOT / item).is_file():
                errors.append(f"{label}: missing legal evidence {item!r}")
        if not row["license"] or not row["derivation"]:
            errors.append(f"{label}: missing license or derivation")
        if row["review_status"] != "approved":
            errors.append(f"{label}: not approved")
    if seen != FORMATS:
        errors.append(f"showcase: format mismatch missing={sorted(FORMATS-seen)} extra={sorted(seen-FORMATS)}")
    if total > 15 * 1024 * 1024:
        errors.append(f"showcase: {total} bytes exceeds 15 MiB budget")
    actual = {
        str(path.relative_to(ROOT))
        for path in ROOT.glob("*/*")
        if path.is_file()
        and path.parent.name in FORMATS
        and path.name not in {"result.md", "diagnostics.txt"}
    }
    if actual != listed:
        errors.append(f"showcase: unlisted={sorted(actual-listed)} missing={sorted(listed-actual)}")
    if set(result_manifest) != FORMATS:
        errors.append("showcase: result manifest does not cover every format exactly once")
    result_bytes = 0
    for fmt, row in result_manifest.items():
        label = f"showcase-result:{fmt}"
        rel = row["result_path"]
        markdown = ROOT / rel
        if not safe(rel) or not markdown.is_file():
            errors.append(f"{label}: missing or unsafe result path")
            continue
        result_bytes += markdown.stat().st_size
        if str(markdown.stat().st_size) != row["bytes"] or digest(markdown) != row["sha256"]:
            errors.append(f"{label}: result size or SHA-256 mismatch")
        directory = markdown.parent
        assets = [path for path in directory.rglob("*") if path.is_file() and "assets" in path.parts]
        diagnostics = directory / "diagnostics.txt"
        diagnostic_lines = len(diagnostics.read_text(encoding="utf-8").splitlines()) if diagnostics.is_file() else 0
        if str(len(assets)) != row["asset_count"]:
            errors.append(f"{label}: asset count mismatch")
        if str(diagnostic_lines) != row["diagnostic_lines"]:
            errors.append(f"{label}: diagnostic line count mismatch")
        text = markdown.read_text(encoding="utf-8")
        for reference in re.findall(r"\]\((assets/[^)]+)\)", text):
            target = directory / unquote(reference.split(' "', 1)[0])
            if not target.is_file():
                errors.append(f"{label}: broken local asset reference {reference!r}")
            elif target.suffix.lower() == ".bin":
                errors.append(f"{label}: binary payload cannot be used as an image reference {reference!r}")
            elif not image_magic_matches(target):
                errors.append(f"{label}: asset extension and image magic disagree {reference!r}")
    if result_bytes > 10 * 1024 * 1024:
        errors.append(f"showcase: {result_bytes} result bytes exceeds 10 MiB Markdown budget")
    cli = REPO / "_build/native/release/build/cli/cli.exe"
    converted = 0
    if cli.is_file():
        with tempfile.TemporaryDirectory(prefix="showcase-audit-") as temporary:
            outdir = Path(temporary)
            for row in manifest:
                result = subprocess.run(
                    [str(cli), "balance", str(ROOT / row["path"]), str(outdir / f"{row['format']}.md")],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
                )
                output = outdir / f"{row['format']}.md"
                if result.returncode or not output.is_file() or output.stat().st_size < 20:
                    errors.append(f"showcase:{row['format']}: conversion failed or produced sparse output")
                elif row["format"] in result_manifest and digest(output) != result_manifest[row["format"]]["sha256"]:
                    errors.append(f"showcase:{row['format']}: checked-in result differs from a fresh conversion")
                else:
                    converted += 1
    print(
        f"showcase: {len(manifest)} inputs, {total} input bytes, "
        f"{result_bytes} Markdown bytes, {converted} release conversions checked"
    )


def catalog_area(area: str, errors: list[str]) -> None:
    base = LAB / area
    manifest = tsv(base / "MANIFEST.tsv")
    catalog_rows = tsv(base / "SOURCE_CATALOG.tsv")
    catalog = {row["id"]: row for row in catalog_rows}
    prefixes: list[Path] = []
    for source_id, row in catalog.items():
        if row["redistributable"] != "ok" or not row["license_status"]:
            errors.append(f"{area}:{source_id}: source is not approved for redistribution")
        local = row["source_type"] in {"self_synthetic", "local_generated"}
        if not row["url"].startswith("https://") and not (local and row["url"] == "local-generated"):
            errors.append(f"{area}:{source_id}: invalid source URL")
        if safe(row["local_cache"]):
            prefixes.append(LAB / row["local_cache"])
    for row in manifest:
        label = f"{area}:{row['id']}"
        path = LAB / row["path"]
        if not safe(row["path"]) or not path.is_file():
            errors.append(f"{label}: missing input")
        if row["source_id"] not in catalog:
            errors.append(f"{label}: source absent from catalog")
        else:
            prefixes.append(path.parent)
        if row["license_review_status"] != "approved" or not row["license_status"]:
            errors.append(f"{label}: license is not approved")
        local = row["source_type"] in {"self_synthetic", "local_generated"}
        if not row["original_url"].startswith("https://") and not (
            local and row["original_url"] == "local-generated"
        ):
            errors.append(f"{label}: invalid provenance URL")
    unmanaged = []
    for path in base.rglob("*"):
        if not path.is_file() or path.name in {"MANIFEST.tsv", "SOURCE_CATALOG.tsv", "README.md"}:
            continue
        if "expected" in path.parts or "_audit" in path.parts or path.name.startswith(("LICENSE", "COPYING", "NOTICE")):
            continue
        if not any(path == prefix or prefix in path.parents for prefix in prefixes):
            unmanaged.append(str(path.relative_to(LAB)))
    if unmanaged:
        errors.append(f"{area}: files outside approved source caches: {unmanaged[:10]}")
    print(f"{area}: {len(manifest)} rows, {len(catalog)} source groups checked")


def bench(errors: list[str]) -> None:
    base = LAB / "external_bench"
    manifest = tsv(base / "MANIFEST.tsv")
    for row in manifest:
        label = f"external_bench:{row['bench_id']}"
        if row["source_kind"] == "missing_candidate":
            if row["enabled_tier"] != "disabled" or row["review_status"] != "missing_candidate" or row["bytes"] != "0" or row["sha256"]:
                errors.append(f"{label}: malformed missing-candidate record")
            continue
        path = base / row["rel_path"]
        if not safe(row["rel_path"]) or not path.is_file() or str(path.stat().st_size) != row["bytes"] or digest(path) != row["sha256"]:
            errors.append(f"{label}: missing input or integrity mismatch")
        if row["review_status"] != "accepted" or not row["source_ref"]:
            errors.append(f"{label}: source review is incomplete")
    print(f"external_bench: {len(manifest)} rows checked")


def main_process(errors: list[str]) -> None:
    base = LAB / "external_main_process"
    manifest = tsv(base / "MANIFEST.tsv")
    for row in manifest:
        for field in ("input_path", "expected_path"):
            rel = row[field]
            if rel and (not safe(rel) or not (base / rel).exists()):
                errors.append(f"external_main_process:{row['id']}: missing {field}")
    print(f"external_main_process: {len(manifest)} repository-owned rows checked")


def main() -> int:
    errors: list[str] = []
    showcase(errors)
    if not LAB.is_dir():
        errors.append("quality-lab checkout is missing")
    else:
        catalog_area("external_quality", errors)
        catalog_area("external_accurate", errors)
        bench(errors)
        main_process(errors)
    if errors:
        print("sample audit: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("sample audit: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
