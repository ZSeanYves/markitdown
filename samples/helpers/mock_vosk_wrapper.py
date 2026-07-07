#!/usr/bin/env python3
"""Deterministic local Vosk wrapper mock for tests and sample regression."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    args = sys.argv[1:]
    if "--help" in args or "-h" in args:
        print(
            "usage: mock_vosk_wrapper.py <input_audio_path> <output_json_path> [--lang <LANG>]"
        )
        return 0

    if len(args) < 2:
        print("missing required args", file=sys.stderr)
        return 2

    input_path = Path(args[0])
    output_path = Path(args[1])
    language = "auto"
    index = 2
    while index < len(args):
        if args[index] == "--lang" and index + 1 < len(args):
            language = args[index + 1].strip() or "auto"
            index += 2
            continue
        print(f"unexpected argument: {args[index]}", file=sys.stderr)
        return 2

    if not input_path.exists():
        print(f"source missing: {input_path}", file=sys.stderr)
        return 3

    result_language = "en" if language == "auto" else language
    payload = {
        "provider_name": "vosk",
        "provider_version": "0.test",
        "metadata": {
            "duration_ms": 7200,
            "sample_rate_hz": 16000,
            "channel_count": 1,
            "codec": input_path.suffix.removeprefix(".") or "audio",
            "language": result_language,
        },
        "segments": [
            {
                "segment_id": "seg-1",
                "start_ms": 0,
                "end_ms": 3200,
                "text": f"{input_path.name} hello",
                "confidence": 0.98,
                "language": result_language,
            },
            {
                "segment_id": "seg-2",
                "start_ms": 3200,
                "end_ms": 7200,
                "text": "world",
                "confidence": 0.97,
                "language": result_language,
            },
        ],
        "diagnostics": ["mock=true"],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload), encoding="utf-8")
    print("mock vosk stdout")
    print("mock vosk stderr", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
