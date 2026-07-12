#!/usr/bin/env python3
"""Deterministic local Vosk wrapper mock for tests and sample regression."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    args = sys.argv[1:]
    if "--help" in args or "-h" in args:
        print("usage: mock_vosk_wrapper.py --request-json <request_json_path> --result-json <result_json_path>")
        return 0

    request_json_path: Path | None = None
    output_path: Path | None = None
    index = 0
    while index < len(args):
        if args[index] == "--request-json" and index + 1 < len(args):
            request_json_path = Path(args[index + 1])
            index += 2
            continue
        if args[index] == "--result-json" and index + 1 < len(args):
            output_path = Path(args[index + 1])
            index += 2
            continue
        print(f"unexpected argument: {args[index]}", file=sys.stderr)
        return 2

    if request_json_path is None or output_path is None:
        print("missing required args", file=sys.stderr)
        return 2

    try:
        request = json.loads(request_json_path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"request JSON unreadable: {exc}", file=sys.stderr)
        return 2
    if not isinstance(request, dict):
        print("request JSON root must be an object", file=sys.stderr)
        return 2

    input_path = Path(str(request.get("input_audio_path", "")))
    normalized_path_raw = str(request.get("normalized_audio_path", "") or "").strip()
    backend_input_path = Path(normalized_path_raw) if normalized_path_raw else input_path
    language = str(request.get("language", "auto") or "auto").strip() or "auto"

    if not input_path.exists():
        print(f"source missing: {input_path}", file=sys.stderr)
        return 3
    if not backend_input_path.exists():
        print(f"backend input missing: {backend_input_path}", file=sys.stderr)
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
                "text": f"{backend_input_path.name} hello",
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
