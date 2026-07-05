#!/usr/bin/env python3
import json
import os
import sys


def main() -> int:
    args = sys.argv[1:]
    if len(args) < 3 or args[1] != "--format":
      print("usage error", file=sys.stderr)
      return 2
    audio_path = args[0]
    fmt = args[2]
    lang = None
    if len(args) >= 5 and args[3] == "--lang":
      lang = args[4]
    name = os.path.basename(audio_path)
    payload = {
        "provider_name": "mock_audio_bridge",
        "provider_version": "p0",
        "metadata": {
            "duration_ms": 7200,
            "sample_rate_hz": 16000,
            "channel_count": 1,
            "codec": fmt,
            "language": lang or "und",
        },
        "segments": [
            {
                "segment_id": f"{fmt}-seg-1",
                "start_ms": 0,
                "end_ms": 3200,
                "text": f"{name} hello",
                "language": lang or "und",
                "confidence": 0.98,
            },
            {
                "segment_id": f"{fmt}-seg-2",
                "start_ms": 3200,
                "end_ms": 7200,
                "text": f"{fmt} world",
                "language": lang or "und",
                "confidence": 0.97,
            },
        ],
        "diagnostics": [f"format={fmt}"],
    }
    print(json.dumps(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
