#!/usr/bin/env python3
"""Small wrapper that gives markitdown a stable audio command contract."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


DEFAULT_MODEL_PATH = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    / "markitdown"
    / "whisper.cpp"
    / "ggml-base.bin"
)


def usage() -> str:
    return (
        "usage: audio_transcribe_wrapper.py <input_audio_path> <output_json_path> "
        "[--lang <LANG>]"
    )


def parse_args(argv: list[str]) -> tuple[Path, Path, str]:
    if not argv or "--help" in argv or "-h" in argv:
        print(usage())
        raise SystemExit(0)

    if len(argv) < 2:
        print(usage(), file=sys.stderr)
        raise SystemExit(2)

    input_path = Path(argv[0])
    output_json_path = Path(argv[1])
    language = "auto"

    index = 2
    while index < len(argv):
        arg = argv[index]
        if arg == "--lang" and index + 1 < len(argv):
            language = argv[index + 1].strip() or "auto"
            index += 2
            continue
        print(f"unexpected argument: {arg}", file=sys.stderr)
        raise SystemExit(2)

    return input_path, output_json_path, language.lower()


def resolve_backend() -> str:
    for candidate in ("whisper-cli", "main"):
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    print(
        "whisper.cpp CLI is unavailable. Install `whisper-cli` or expose `main` on PATH.",
        file=sys.stderr,
    )
    raise SystemExit(3)


def resolve_model_path() -> Path:
    raw = os.environ.get("MARKITDOWN_AUDIO_MODEL_PATH", "").strip()
    model_path = Path(raw) if raw else DEFAULT_MODEL_PATH
    if model_path.is_file():
        return model_path
    print(
        "Whisper model is unavailable. Set MARKITDOWN_AUDIO_MODEL_PATH or place "
        f"`ggml-base.bin` at `{model_path}`.",
        file=sys.stderr,
    )
    raise SystemExit(4)


def output_base_from_json_path(output_json_path: Path) -> Path:
    if output_json_path.suffix == ".json":
        return output_json_path.with_suffix("")
    return output_json_path


def main() -> int:
    input_path, output_json_path, language = parse_args(sys.argv[1:])
    if not input_path.is_file():
        print(f"audio input is missing: {input_path}", file=sys.stderr)
        return 2

    backend = resolve_backend()
    model_path = resolve_model_path()
    output_base = output_base_from_json_path(output_json_path)
    output_base.parent.mkdir(parents=True, exist_ok=True)

    cmd = [
        backend,
        "-m",
        str(model_path),
        "-f",
        str(input_path),
        "-ojf",
        "-of",
        str(output_base),
        "-np",
        "-l",
        language,
    ]
    completed = subprocess.run(cmd)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
