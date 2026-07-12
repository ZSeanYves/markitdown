#!/usr/bin/env python3
"""Summarize MoonBit Cobertura output using product-layer thresholds."""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


GROUPS = (
    ("core", 90.0, ("input/", "convert/", "parser/", "pipeline/", "runtime/", "render/", "core/", "product/", "rag/")),
    ("formats", 80.0, ("formats/", "format_readers/", "container/", "internal/formats/", "internal/format_readers/")),
    ("tools", 70.0, ("cli/", "bench/")),
)

EXTERNAL_RUNTIME_ADAPTERS = {
    "formats/audio/runtime.mbt",
    "formats/ocr/runtime.mbt",
    "formats/ocr/tesseract.mbt",
    "formats/pdf/ocr_runtime.mbt",
}

EXCLUDED_FILES = {
    "format_readers/pdf/font_encoding_tables.mbt",
    "format_readers/pdf/gb2312_data.mbt",
    "format_readers/pdf/predefined_cmap_data.mbt",
}


def classify(filename: str) -> tuple[str, float] | None:
    if filename in EXTERNAL_RUNTIME_ADAPTERS:
        return "tools", 70.0
    for name, threshold, prefixes in GROUPS:
        if filename.startswith(prefixes):
            return name, threshold
    return None


def summarize(path: Path) -> dict:
    root = ET.parse(path).getroot()
    totals: dict[str, dict[str, float | int]] = defaultdict(
        lambda: {"covered": 0, "valid": 0, "threshold": 0.0}
    )
    files = []
    for node in root.findall(".//class"):
        filename = node.attrib["filename"]
        group = classify(filename)
        if group is None or filename in EXCLUDED_FILES:
            continue
        group_name, threshold = group
        lines = node.findall("./lines/line")
        valid = len(lines)
        covered = sum(int(line.attrib.get("hits", "0")) > 0 for line in lines)
        totals[group_name]["covered"] += covered
        totals[group_name]["valid"] += valid
        totals[group_name]["threshold"] = threshold
        files.append({"path": filename, "group": group_name, "covered": covered, "valid": valid})
    groups = []
    for name, threshold, _prefixes in GROUPS:
        values = totals[name]
        valid = int(values["valid"])
        covered = int(values["covered"])
        rate = 100.0 if valid == 0 else covered * 100.0 / valid
        groups.append({
            "name": name,
            "covered": covered,
            "valid": valid,
            "rate": round(rate, 4),
            "threshold": threshold,
            "passed": rate >= threshold,
        })
    files.sort(key=lambda item: (item["group"], item["covered"] / item["valid"] if item["valid"] else 1.0, item["path"]))
    return {
        "schema_version": 1,
        "groups": groups,
        "files": files,
        "excluded_files": sorted(EXCLUDED_FILES),
        "passed": all(group["passed"] for group in groups),
    }


def write_outputs(summary: dict, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "coverage.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    tsv = ["group\tcovered\tvalid\trate\tthreshold\tpassed"]
    markdown = ["# Coverage Gate", "", "| Group | Covered | Valid | Rate | Threshold | Status |", "| --- | ---: | ---: | ---: | ---: | --- |"]
    for group in summary["groups"]:
        status = "pass" if group["passed"] else "fail"
        tsv.append(f'{group["name"]}\t{group["covered"]}\t{group["valid"]}\t{group["rate"]:.4f}\t{group["threshold"]:.1f}\t{status}')
        markdown.append(f'| {group["name"]} | {group["covered"]} | {group["valid"]} | {group["rate"]:.2f}% | {group["threshold"]:.0f}% | {status} |')
    (output_dir / "coverage.tsv").write_text("\n".join(tsv) + "\n", encoding="utf-8")
    (output_dir / "coverage.md").write_text("\n".join(markdown) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cobertura", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()
    summary = summarize(Path(args.cobertura))
    write_outputs(summary, Path(args.output_dir))
    return 1 if args.enforce and not summary["passed"] else 0


if __name__ == "__main__":
    sys.exit(main())
