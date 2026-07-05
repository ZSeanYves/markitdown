#!/usr/bin/env python3
"""Deterministic ffmpeg mock for m4a normalization tests."""

from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    args = sys.argv[1:]
    if len(args) < 2:
      print("usage error", file=sys.stderr)
      return 2
    output_path = Path(args[-1])
    output_path.write_text("RIFFmockWAVE", encoding="utf-8")
    print("mock ffmpeg stderr", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
