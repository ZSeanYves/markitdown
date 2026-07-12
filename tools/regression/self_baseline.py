#!/usr/bin/env python3
"""Capture and enforce platform-specific self-performance baselines."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import statistics
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def command_text(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def runtime_fingerprint(root: Path) -> str:
    digest = hashlib.sha256()
    fingerprint_dir = root / "env" / "fingerprints"
    for path in sorted(fingerprint_dir.glob("*.json")):
        digest.update(path.name.encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def current_fingerprints(root: Path) -> dict[str, str]:
    return {
        "moonbit": command_text("moon", "version").splitlines()[0],
        "python": platform.python_version(),
        "os": platform.system(),
        "arch": platform.machine(),
        "runtime": runtime_fingerprint(root),
    }


def load_samples(run_dir: Path) -> list[dict]:
    path = run_dir / "results" / "samples.jsonl"
    if not path.is_file():
        raise ValueError(f"missing benchmark samples: {path}")
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def aggregate_cases(samples: list[dict]) -> list[dict]:
    groups: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for sample in samples:
        if sample.get("status") != "ok":
            raise ValueError(
                f"non-ok self-baseline sample: {sample.get('tool')} {sample.get('bench_id')}"
            )
        groups[(sample["bench_id"], sample["tool"])].append(sample)
    cases = []
    for (bench_id, tool), rows in sorted(groups.items()):
        walls = [int(row["wall_us"]) for row in rows]
        peaks = [int(row["peak_rss_kb"]) for row in rows if row.get("peak_rss_kb")]
        hashes = {row.get("output_sha256") for row in rows}
        inputs = {row["input_sha256"] for row in rows}
        if len(rows) < 5 or len(hashes) != 1 or None in hashes or len(inputs) != 1:
            raise ValueError(f"unstable or undersampled self-baseline case: {tool} {bench_id}")
        if tool == "moonbit-cli" and not peaks:
            raise ValueError(f"missing RSS evidence: {tool} {bench_id}")
        cases.append(
            {
                "bench_id": bench_id,
                "tool": tool,
                "input_sha256": next(iter(inputs)),
                "median_wall_us": int(statistics.median(walls)),
                "peak_rss_kb": max(peaks) if peaks else None,
                "output_sha256": next(iter(hashes)),
            }
        )
    return cases


def capture(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    quality = root / "markitdown-quality-lab"
    payload = {
        "schema_version": 1,
        "platform_key": args.platform_key,
        "runner_class": args.runner_class,
        "review_status": args.review_status,
        "main_sha": command_text("git", "-C", str(root), "rev-parse", "HEAD"),
        "quality_sha": command_text("git", "-C", str(quality), "rev-parse", "HEAD"),
        "fingerprints": current_fingerprints(root),
        "cases": aggregate_cases(load_samples(args.run.resolve())),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    return 0


def enforce(args: argparse.Namespace) -> int:
    baseline = json.loads(args.baseline.read_text())
    candidate = json.loads(args.candidate.read_text())
    failures: list[str] = []
    if baseline.get("review_status") != "approved":
        failures.append("baseline is not approved")
    for field in ("platform_key", "runner_class", "fingerprints"):
        if baseline.get(field) != candidate.get(field):
            failures.append(f"fingerprint mismatch: {field}")
    old = {(row["bench_id"], row["tool"]): row for row in baseline.get("cases", [])}
    new = {(row["bench_id"], row["tool"]): row for row in candidate.get("cases", [])}
    if old.keys() != new.keys():
        failures.append("self-baseline case set changed")
    for key in sorted(old.keys() & new.keys()):
        before, after = old[key], new[key]
        if before["input_sha256"] != after["input_sha256"]:
            failures.append(f"input hash changed: {key[1]} {key[0]}")
        if before["output_sha256"] != after["output_sha256"]:
            failures.append(f"output hash changed: {key[1]} {key[0]}")
        for metric in ("median_wall_us", "peak_rss_kb"):
            if before.get(metric) is None or after.get(metric) is None:
                continue
            if after[metric] > before[metric] * 1.10:
                failures.append(f"{metric} regressed >10%: {key[1]} {key[0]}")
    result = {"status": "pass" if not failures else "fail", "failures": failures}
    print(json.dumps(result, sort_keys=True))
    return 0 if not failures else 1


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    sub = result.add_subparsers(dest="command", required=True)
    capture_parser = sub.add_parser("capture")
    capture_parser.add_argument("--root", type=Path, default=Path.cwd())
    capture_parser.add_argument("--run", type=Path, required=True)
    capture_parser.add_argument("--output", type=Path, required=True)
    capture_parser.add_argument("--platform-key", required=True)
    capture_parser.add_argument("--runner-class", required=True)
    capture_parser.add_argument("--review-status", choices=("candidate", "approved"), default="candidate")
    enforce_parser = sub.add_parser("enforce")
    enforce_parser.add_argument("--baseline", type=Path, required=True)
    enforce_parser.add_argument("--candidate", type=Path, required=True)
    return result


def main() -> int:
    args = parser().parse_args()
    return capture(args) if args.command == "capture" else enforce(args)


if __name__ == "__main__":
    sys.exit(main())
