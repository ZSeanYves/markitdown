#!/usr/bin/env python3
"""Summarize MoonBit Cobertura output using product-layer thresholds."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
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

FORMAT_CONTAINER_PREFIXES = (
    "format_readers/ooxml/",
    "format_readers/odf/",
    "format_readers/subtitles/",
    "format_readers/delimited/",
)

KNOWN_FORMATS = {
    "asciidoc",
    "audio",
    "csv",
    "docx",
    "eml",
    "epub",
    "html",
    "ipynb",
    "json",
    "markdown",
    "ocr",
    "odp",
    "ods",
    "odt",
    "pdf",
    "pptx",
    "rst",
    "srt",
    "tex",
    "toml",
    "tsv",
    "txt",
    "vtt",
    "xlsx",
    "xml",
    "yaml",
    "zip",
}


def classify(filename: str) -> tuple[str, float] | None:
    if filename in EXTERNAL_RUNTIME_ADAPTERS:
        return "tools", 70.0
    for name, threshold, prefixes in GROUPS:
        if filename.startswith(prefixes):
            return name, threshold
    return None


def classify_format(filename: str) -> str | None:
    for prefix in FORMAT_CONTAINER_PREFIXES:
        if filename.startswith(prefix):
            remainder = filename[len(prefix):]
            name = remainder.split("/", 1)[0]
            if name in KNOWN_FORMATS:
                return name
    for prefix in ("formats/", "format_readers/", "internal/formats/"):
        if filename.startswith(prefix):
            remainder = filename[len(prefix):]
            name = remainder.split("/", 1)[0]
            if name in KNOWN_FORMATS:
                return name
    return None


def aggregate_formats(files: list[dict]) -> list[dict]:
    totals: dict[str, dict[str, int]] = defaultdict(lambda: {"covered": 0, "valid": 0})
    for item in files:
        name = classify_format(item["path"])
        if name is None:
            continue
        totals[name]["covered"] += int(item["covered"])
        totals[name]["valid"] += int(item["valid"])
    formats = []
    for name in sorted(totals):
        covered = totals[name]["covered"]
        valid = totals[name]["valid"]
        rate = 100.0 if valid == 0 else covered * 100.0 / valid
        formats.append({
            "name": name,
            "covered": covered,
            "valid": valid,
            "rate": round(rate, 4),
        })
    return formats


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
        "formats": aggregate_formats(files),
        "excluded_files": sorted(EXCLUDED_FILES),
        "passed": all(group["passed"] for group in groups),
    }


def format_ratchet(summary: dict, baseline_path: Path | None, max_drop: float) -> dict:
    if baseline_path is None:
        return {"status": "not_configured", "max_drop": max_drop, "entries": [], "passed": True}
    if not baseline_path.is_file():
        return {"status": "baseline_missing", "max_drop": max_drop, "entries": [], "passed": False}
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    baseline_formats = baseline.get("formats") or aggregate_formats(baseline.get("files", []))
    baseline_rates = {item["name"]: float(item["rate"]) for item in baseline_formats}
    current_rates = {item["name"]: float(item["rate"]) for item in summary["formats"]}
    entries = []
    for name in sorted(set(baseline_rates) & set(current_rates)):
        drop = baseline_rates[name] - current_rates[name]
        entries.append({
            "name": name,
            "baseline_rate": round(baseline_rates[name], 4),
            "current_rate": round(current_rates[name], 4),
            "drop": round(drop, 4),
            "passed": drop <= max_drop,
        })
    passed = all(item["passed"] for item in entries)
    return {"status": "pass" if passed else "fail", "max_drop": max_drop, "entries": entries, "passed": passed}


def added_lines_since(baseline_ref: str) -> dict[str, set[int]]:
    completed = subprocess.run(
        [
            "git",
            "diff",
            "--unified=0",
            "--diff-filter=AM",
            baseline_ref,
            "--",
            ":(glob)**/*.mbt",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    added: dict[str, set[int]] = defaultdict(set)
    current_path: str | None = None
    for line in completed.stdout.splitlines():
        if line.startswith("+++ b/"):
            current_path = line[6:]
            continue
        if not line.startswith("@@ ") or current_path is None:
            continue
        match = re.search(r"\+(\d+)(?:,(\d+))?", line)
        if match is None:
            continue
        start = int(match.group(1))
        count = int(match.group(2) or "1")
        added[current_path].update(range(start, start + count))
    return added


def new_code_coverage(cobertura: Path, baseline_ref: str | None, threshold: float) -> dict:
    if baseline_ref is None:
        return {"status": "not_configured", "covered": 0, "valid": 0, "rate": 100.0, "threshold": threshold, "passed": True}
    try:
        added = added_lines_since(baseline_ref)
    except subprocess.CalledProcessError as error:
        return {"status": "baseline_ref_unavailable", "covered": 0, "valid": 0, "rate": 0.0, "threshold": threshold, "passed": False, "error": error.stderr.strip()}
    covered = 0
    valid = 0
    root = ET.parse(cobertura).getroot()
    for node in root.findall(".//class"):
        filename = node.attrib["filename"]
        if (
            filename in EXCLUDED_FILES
            or classify(filename) is None
            or filename.endswith("_test.mbt")
            or filename.endswith("_wbtest.mbt")
        ):
            continue
        changed = added.get(filename, set())
        if not changed:
            continue
        for line in node.findall("./lines/line"):
            if int(line.attrib["number"]) in changed:
                valid += 1
                covered += int(line.attrib.get("hits", "0")) > 0
    rate = 100.0 if valid == 0 else covered * 100.0 / valid
    passed = rate >= threshold
    return {
        "status": "pass" if passed else "fail",
        "covered": covered,
        "valid": valid,
        "rate": round(rate, 4),
        "threshold": threshold,
        "passed": passed,
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
    ratchet = summary.get(
        "format_ratchet",
        {"status": "not_configured", "entries": [], "passed": True},
    )
    markdown.extend(["", "## Format Ratchet", "", "| Format | Baseline | Current | Drop | Status |", "| --- | ---: | ---: | ---: | --- |"])
    for item in ratchet["entries"]:
        status = "pass" if item["passed"] else "fail"
        markdown.append(f'| {item["name"]} | {item["baseline_rate"]:.2f}% | {item["current_rate"]:.2f}% | {item["drop"]:.2f} pp | {status} |')
    new_code = summary.get(
        "new_code",
        {
            "status": "not_configured",
            "covered": 0,
            "valid": 0,
            "rate": 100.0,
            "threshold": 80.0,
            "passed": True,
        },
    )
    markdown.extend([
        "",
        "## New Production Code",
        "",
        f'- Status: {new_code["status"]}',
        f'- Coverage: {new_code["rate"]:.2f}% ({new_code["covered"]}/{new_code["valid"]})',
        f'- Threshold: {new_code["threshold"]:.0f}%',
    ])
    (output_dir / "coverage.tsv").write_text("\n".join(tsv) + "\n", encoding="utf-8")
    (output_dir / "coverage.md").write_text("\n".join(markdown) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cobertura", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--enforce", action="store_true")
    parser.add_argument("--baseline")
    parser.add_argument("--baseline-ref")
    parser.add_argument("--max-format-drop", type=float, default=0.5)
    parser.add_argument("--new-code-threshold", type=float, default=80.0)
    args = parser.parse_args()
    summary = summarize(Path(args.cobertura))
    summary["format_ratchet"] = format_ratchet(
        summary,
        Path(args.baseline) if args.baseline else None,
        args.max_format_drop,
    )
    summary["new_code"] = new_code_coverage(
        Path(args.cobertura),
        args.baseline_ref,
        args.new_code_threshold,
    )
    summary["passed"] = (
        summary["passed"]
        and summary["format_ratchet"]["passed"]
        and summary["new_code"]["passed"]
    )
    write_outputs(summary, Path(args.output_dir))
    return 1 if args.enforce and not summary["passed"] else 0


if __name__ == "__main__":
    sys.exit(main())
