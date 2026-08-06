#!/usr/bin/env python3
"""Collect and verify the reproducible Phase 0 project baseline.

The collector only inventories Git-tracked project files. Generated build output,
the local virtual environments, and a dirty working tree are never incorporated
into the committed baseline. This keeps the manifest stable on developer hosts.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "tools/governance/phase0-baseline.json"
FIXTURE_HASHES = ROOT / "tools/governance/fixtures.sha256"
LOCK = ROOT / "tools/env/config/python/bench.lock"
CI = ROOT / ".github/workflows/ci.yml"


def git_files() -> list[str]:
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return sorted(item for item in raw.decode().split("\0") if item)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def fixture_paths(files: list[str]) -> list[str]:
    prefixes = ("samples/fixtures/contracts/", "samples/fixtures/rejections/")
    return sorted(path for path in files if path.startswith(prefixes))


def fixture_digest(files: list[str]) -> tuple[list[str], str]:
    lines: list[str] = []
    for path in fixture_paths(files):
        digest = sha256_file(ROOT / path)
        lines.append(f"{digest}  {path}")
    payload = ("\n".join(lines) + "\n").encode("utf-8") if lines else b""
    return lines, sha256_bytes(payload)


def moon_version_output() -> dict[str, str]:
    output = subprocess.check_output(
        ["moon", "version", "--all"], cwd=ROOT, text=True, stderr=subprocess.STDOUT
    )
    patterns = {
        "moon": r"^moon (\S+) \(",
        "moonc": r"^moonc (\S+) ",
        "moonrun": r"^moonrun (\S+) \(",
    }
    result: dict[str, str] = {}
    for line in output.splitlines():
        for key, pattern in patterns.items():
            match = re.search(pattern, line)
            if match:
                result[key] = match.group(1)
    return result


def quality_lab_sha() -> str:
    match = re.search(
        r"MARKITDOWN_QUALITY_LAB_SHA:\s*['\"]?([0-9a-f]{40})",
        CI.read_text(encoding="utf-8"),
    )
    return match.group(1) if match else "missing"


def benchmark_lock_version() -> str:
    for line in LOCK.read_text(encoding="utf-8").splitlines():
        if line.startswith("markitdown=="):
            return line.split("==", 1)[1].strip()
    return "missing"


def project_inventory(files: list[str]) -> dict:
    source = [path for path in files if path.endswith(".mbt")]
    production = [
        path
        for path in source
        if not path.endswith(("_test.mbt", "_wbtest.mbt"))
    ]
    public_lines: list[str] = []
    public_type_lines: list[str] = []
    public_all = 0
    for path in production:
        for index, line in enumerate((ROOT / path).read_text(encoding="utf-8").splitlines(), 1):
            if re.match(r"^\s*pub(?:\(all\))?(?:\s|$)", line):
                public_lines.append(f"{path}:{index}")
                if re.match(r"^\s*pub\(all\)(?:\s|$)", line):
                    public_all += 1
                if re.match(r"^\s*pub(?:\(all\))?\s+(?:struct|enum|type|trait|suberror)(?:\s|$)", line):
                    public_type_lines.append(f"{path}:{index}")
    interfaces = [path for path in files if path.endswith("pkg.generated.mbti")]
    interface_lines = sum(
        (ROOT / path).read_text(encoding="utf-8").count("\n") for path in interfaces
    )
    ffi_files = [path for path in files if path.endswith(".c")]
    ffi_mbt = [
        path
        for path in production
        if 'extern "C"' in (ROOT / path).read_text(encoding="utf-8")
    ]
    return {
        "moon_packages": len([path for path in files if path == "moon.pkg" or path.endswith("/moon.pkg")]),
        "moonbit_files": len(source),
        "production_moonbit_files": len(production),
        "generated_interfaces": len(interfaces),
        "generated_interface_lines": interface_lines,
        "public_declarations": len(public_lines),
        "pub_all_declarations": public_all,
        "public_type_declarations": len(public_type_lines),
        "native_c_files": len(ffi_files),
        "moonbit_ffi_files": len(ffi_mbt),
        "production_file_examples": production[:12],
    }


def collect() -> tuple[dict, list[str]]:
    files = git_files()
    fixture_lines, fixture_hash = fixture_digest(files)
    inventory = project_inventory(files)
    manifest = {
        "schema_version": 1,
        "baseline_name": "phase-0",
        "recorded_commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "recorded_date": "2026-08-05",
        "module": {"name": "ZSeanYves/markitdown", "version": "0.7.0"},
        "upstream": {
            "project": "microsoft/markitdown",
            "tag": "v0.1.7",
            "commit": "fd239d5d2be43d9b68329730206b9312c7d5a388",
            "source": "https://github.com/microsoft/markitdown/releases/tag/v0.1.7",
        },
        "toolchain": moon_version_output(),
        "native_baseline": {
            "backend": "c-and-new-native",
            "env": {"MOONBIT_NEW_NATIVE": "0-and-1"},
            "targets": {
                "native": {"tests": 894, "passed": 894},
                "js": {"tests": 485, "passed": 485},
                "wasm": {"tests": 485, "passed": 485},
                "wasm-gc": {"tests": 485, "passed": 485},
            },
            "new_native_canary": "full 894-test native suite passes and is a blocking macOS/Linux CI matrix",
        },
        "benchmark_baseline": {
            "python_version": "3.11",
            "markitdown_version": benchmark_lock_version(),
            "lock_path": "tools/env/config/python/bench.lock",
            "lock_sha256": sha256_file(LOCK),
            "quality_lab_commit": quality_lab_sha(),
        },
        "inventory": inventory,
        "fixtures": {
            "roots": ["samples/fixtures/contracts", "samples/fixtures/rejections"],
            "file_count": len(fixture_lines),
            "manifest_sha256": fixture_hash,
            "manifest_path": "tools/governance/fixtures.sha256",
        },
        "working_tree_policy": "CI requires a clean checkout; local generated output is never baseline input",
    }
    return manifest, fixture_lines


def immutable_fields(manifest: dict) -> dict:
    return {
        "upstream": manifest["upstream"],
        "toolchain": manifest["toolchain"],
        "benchmark_baseline": manifest["benchmark_baseline"],
        "fixtures": manifest["fixtures"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="write the baseline and fixture hash manifest")
    parser.add_argument("--check", action="store_true", help="verify immutable baseline inputs")
    args = parser.parse_args()
    if args.write == args.check:
        parser.error("choose exactly one of --write or --check")
    observed, fixture_lines = collect()
    if args.write:
        BASELINE.write_text(json.dumps(observed, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        FIXTURE_HASHES.write_text("\n".join(fixture_lines) + "\n", encoding="utf-8")
        print(json.dumps(observed, indent=2, sort_keys=True))
        return 0
    if not BASELINE.is_file() or not FIXTURE_HASHES.is_file():
        print("Phase 0 baseline files are missing; run --write", file=sys.stderr)
        return 1
    expected = json.loads(BASELINE.read_text(encoding="utf-8"))
    errors: list[str] = []
    if immutable_fields(expected) != immutable_fields(observed):
        errors.append("immutable baseline inputs changed; update deliberately and review the diff")
    expected_lines = FIXTURE_HASHES.read_text(encoding="utf-8")
    actual_lines = "\n".join(fixture_lines) + "\n"
    if expected_lines != actual_lines:
        errors.append("fixture hash manifest changed")
    if errors:
        for error in errors:
            print(f"baseline mismatch: {error}", file=sys.stderr)
        return 1
    print("Phase 0 immutable baseline matches")
    print(json.dumps({"observed_inventory": observed["inventory"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
