#!/usr/bin/env python3
"""Generate table-like PPTX samples for local regression.

Note: this script is optional local tooling and is not invoked in CI.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "samples" / "pptx"
EXPECTED = ROOT / "samples" / "expected" / "pptx"


if __name__ == "__main__":
    SAMPLES.mkdir(parents=True, exist_ok=True)
    EXPECTED.mkdir(parents=True, exist_ok=True)
    print("No default sample generation configured.")
