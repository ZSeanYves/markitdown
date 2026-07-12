#!/usr/bin/env python3
"""Run a deterministic malformed-input smoke corpus through the native CLI."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
import subprocess
from pathlib import Path


FORMATS = ("pdf", "zip", "docx", "xlsx", "pptx", "epub", "xml", "html", "eml")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--quality-lab", default="markitdown-quality-lab")
    parser.add_argument("--cli", default="_build/native/release/build/cli/cli.exe")
    parser.add_argument("--output", default=".tmp/mutation/summary.json")
    parser.add_argument("--timeout-seconds", type=float, default=15.0)
    return parser.parse_args()


def select_seeds(lab: Path) -> dict[str, Path]:
    manifest = lab / "external_main_process" / "MANIFEST.tsv"
    seeds: dict[str, Path] = {}
    with manifest.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            fmt = row["format"]
            if fmt not in FORMATS or fmt in seeds or row["lane"] != "markdown":
                continue
            path = lab / "external_main_process" / row["input_path"]
            if path.is_file():
                seeds[fmt] = path
    missing = sorted(set(FORMATS) - set(seeds))
    if missing:
        raise RuntimeError(f"missing mutation seeds: {', '.join(missing)}")
    return seeds


def mutations(data: bytes) -> list[tuple[str, bytes]]:
    if not data:
        return [("append_nul", b"\0")]
    middle = len(data) // 2
    flipped = bytearray(data)
    flipped[middle] ^= 0x5A
    return [
        ("truncate_half", data[:middle]),
        ("flip_middle", bytes(flipped)),
        ("append_nul", data + b"\0"),
    ]


def run_once(cli: Path, fmt: str, case: Path, output: Path, timeout: float) -> dict[str, object]:
    try:
        completed = subprocess.run(
            [str(cli), "balance", "--format", fmt, str(case), str(output)],
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return {"timed_out": True, "returncode": None, "output_sha256": None}
    digest = None
    output_bytes = 0
    if completed.returncode == 0 and output.is_file():
        output_data = output.read_bytes()
        output_bytes = len(output_data)
        digest = hashlib.sha256(output_data).hexdigest()
    return {
        "timed_out": False,
        "returncode": completed.returncode,
        "output_sha256": digest,
        "output_bytes": output_bytes,
        "stdout_bytes": len(completed.stdout),
        "stderr_bytes": len(completed.stderr),
        "stdout_sha256": hashlib.sha256(completed.stdout).hexdigest(),
        "stderr_sha256": hashlib.sha256(completed.stderr).hexdigest(),
    }


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    lab = (root / args.quality_lab).resolve()
    cli = (root / args.cli).resolve()
    output = (root / args.output).resolve()
    if not cli.is_file():
        raise SystemExit(f"native CLI is missing: {cli}")
    work = root / ".tmp" / "mutation" / "cases"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    results: list[dict[str, object]] = []
    failures: list[str] = []
    for fmt, seed in select_seeds(lab).items():
        for mutation, data in mutations(seed.read_bytes()):
            case = work / f"{fmt}-{mutation}{seed.suffix}"
            case.write_bytes(data)
            runs = []
            for repeat in range(2):
                converted = work / f"{fmt}-{mutation}-{repeat}.md"
                runs.append(run_once(cli, fmt, case, converted, args.timeout_seconds))
            deterministic = runs[0] == runs[1]
            controlled = all(
                not run["timed_out"]
                and (
                    (run["returncode"] == 0 and run.get("output_bytes", 0) > 0)
                    or (
                        run["returncode"] == 1
                        and run.get("stderr_bytes", 0) > 0
                        and run.get("stdout_bytes", 0) == 0
                    )
                )
                for run in runs
            )
            if not deterministic or not controlled:
                failures.append(f"{fmt}:{mutation}")
            results.append({
                "format": fmt,
                "mutation": mutation,
                "seed": str(seed.relative_to(root)),
                "input_bytes": len(data),
                "deterministic": deterministic,
                "controlled": controlled,
                "runs": runs,
            })
    payload = {
        "schema_version": 1,
        "case_count": len(results),
        "failure_count": len(failures),
        "failures": failures,
        "results": results,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
