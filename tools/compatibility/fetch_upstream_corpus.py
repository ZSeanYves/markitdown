#!/usr/bin/env python3
"""Fetch and verify the exact MarkItDown v0.1.7 reference fixtures."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/compatibility/contract-manifest.json"

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / ".tmp/compatibility/upstream-v0.1.7")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    base = "https://raw.githubusercontent.com/microsoft/markitdown/" + data["upstream"]["commit"] + "/" + data["upstream"]["test_root"] + "/"
    errors = []
    for name, expected in data["upstream_files"].items():
        target = args.output / name
        if not target.is_file() and args.check:
            errors.append(f"missing upstream fixture: {name}")
            continue
        if not target.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            try:
                with urlopen(base + name, timeout=60) as response:
                    target.write_bytes(response.read())
            except Exception:
                # Reference-only web fixtures live beside the format corpus.
                reference_base = base.replace("/test_files/", "/")
                with urlopen(reference_base + name, timeout=60) as response:
                    target.write_bytes(response.read())
        actual = digest(target.read_bytes())
        if actual != expected:
            errors.append(f"hash mismatch for {name}: expected {expected}, got {actual}")
    if errors:
        for error in errors:
            print("Phase 2 upstream corpus: " + error, file=sys.stderr)
        return 1
    print(f"verified {len(data['upstream_files'])} MarkItDown {data['upstream']['tag']} fixtures under {args.output}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
