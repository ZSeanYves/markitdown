#!/usr/bin/env python3
"""Verify that the MoonBit components and backend match the Phase 0 pin."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PIN = ROOT / "tools/governance/toolchain.json"


def moon_versions(output: str) -> dict[str, str]:
    result: dict[str, str] = {}
    patterns = {
        "moon_version": r"^moon (\S+) \(",
        "moonc_version": r"^moonc (\S+) ",
        "moonrun_version": r"^moonrun (\S+) \(",
    }
    for line in output.splitlines():
        for key, pattern in patterns.items():
            match = re.search(pattern, line)
            if match:
                result[key] = match.group(1)
    return result


def read_pin() -> dict:
    return json.loads(PIN.read_text(encoding="utf-8"))


def verify() -> list[str]:
    pin = read_pin()
    moon = shutil.which("moon")
    if moon is None:
        return ["moon is not on PATH"]
    try:
        output = subprocess.check_output(
            [moon, "version", "--all"], cwd=ROOT, text=True, stderr=subprocess.STDOUT
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        return [f"cannot run moon version --all: {exc}"]
    observed = moon_versions(output)
    errors: list[str] = []
    expected_values = {
        "moon_version": os.environ.get("MOONBIT_VERSION", pin["moon_version"]),
        "moonc_version": os.environ.get("MOONBIT_EXPECTED_MOONC", pin["moonc_version"]),
        "moonrun_version": pin["moonrun_version"],
    }
    for key in ("moon_version", "moonc_version", "moonrun_version"):
        expected = expected_values[key]
        actual = observed.get(key)
        if actual != expected:
            errors.append(f"{key}: expected {expected!r}, observed {actual!r}")
    expected_backend = pin.get("native_backend_env", {})
    for key, expected in expected_backend.items():
        actual = os.environ.get(key)
        if actual != expected:
            errors.append(f"{key}: expected {expected!r}, observed {actual!r}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--print", action="store_true", dest="print_versions")
    args = parser.parse_args()
    errors = verify()
    if args.print_versions:
        print(json.dumps(read_pin(), indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print(f"toolchain mismatch: {error}", file=sys.stderr)
        return 1
    print("MoonBit toolchain matches Phase 0 pin")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
