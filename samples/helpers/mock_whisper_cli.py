#!/usr/bin/env python3
"""Deterministic whisper.cpp CLI mock for tests and sample regression."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def arg_value(args: list[str], *flags: str) -> str | None:
    for index, arg in enumerate(args):
        if arg in flags and index + 1 < len(args):
            return args[index + 1]
    return None


def main() -> int:
    args = sys.argv[1:]
    if "--help" in args:
      print("mock whisper-cli help")
      return 0

    model = arg_value(args, "-m", "--model")
    source = arg_value(args, "-f", "--file")
    output_base = arg_value(args, "-of", "--output-file")
    language = arg_value(args, "-l", "--language") or "auto"

    if model is None or source is None or output_base is None:
      print("missing required args", file=sys.stderr)
      return 2

    source_path = Path(source)
    if not source_path.exists():
      print(f"source missing: {source}", file=sys.stderr)
      return 3

    result_language = language if language != "auto" else "en"
    output_path = Path(output_base + ".json")
    payload = {
        "params": {
            "model": model,
            "language": language,
            "translate": False,
        },
        "result": {
            "language": result_language,
        },
        "transcription": [
            {
                "offsets": {"from": 0, "to": 3200},
                "text": f"{source_path.name} hello",
                "tokens": [
                    {"text": "hello", "id": 1, "p": 0.98, "t_dtw": 0.0}
                ],
            },
            {
                "offsets": {"from": 3200, "to": 7200},
                "text": "world",
                "tokens": [
                    {"text": "world", "id": 2, "p": 0.97, "t_dtw": 0.0}
                ],
            },
        ],
    }
    output_path.write_text(json.dumps(payload), encoding="utf-8")
    print("mock whisper stdout")
    print("mock whisper stderr", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
