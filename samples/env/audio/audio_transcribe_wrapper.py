#!/usr/bin/env python3
"""Stable local Vosk wrapper used by markitdown audio routes."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path


DEFAULT_MODEL_PATH = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    / "markitdown"
    / "vosk"
    / "model"
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


def resolve_model_path() -> Path:
    raw = os.environ.get("MARKITDOWN_AUDIO_MODEL_PATH", "").strip()
    model_path = Path(raw) if raw else DEFAULT_MODEL_PATH
    if model_path.is_dir():
        return model_path
    print(
        "Vosk model directory is unavailable. Set MARKITDOWN_AUDIO_MODEL_PATH or place "
        f"an extracted model at `{model_path}`.",
        file=sys.stderr,
    )
    raise SystemExit(4)


def resolve_provider_version() -> str:
    try:
        import vosk  # type: ignore
    except Exception:
        return ""
    return getattr(vosk, "__version__", "") or ""


def load_vosk() -> tuple[object, object]:
    try:
        from vosk import KaldiRecognizer, Model  # type: ignore
    except Exception as exc:
        print(
            "Vosk Python package is unavailable. Install `vosk` in the active `python3` environment. "
            f"detail: {exc}",
            file=sys.stderr,
        )
        raise SystemExit(3)
    return Model, KaldiRecognizer


def normalize_with_ffmpeg(input_path: Path, codec: str) -> tuple[Path, dict[str, int | str], Path]:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print(
            "ffmpeg is required to normalize compressed audio for the local Vosk backend.",
            file=sys.stderr,
        )
        raise SystemExit(5)

    temp_dir = Path(tempfile.mkdtemp(prefix="markitdown-vosk-"))
    normalized = temp_dir / "normalized.wav"
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(input_path),
        "-ar",
        "16000",
        "-ac",
        "1",
        "-c:a",
        "pcm_s16le",
        str(normalized),
    ]
    completed = subprocess.run(cmd, capture_output=True, text=True)
    if completed.returncode != 0 or not normalized.is_file():
        detail = (completed.stderr or completed.stdout or "ffmpeg normalization failed").strip()
        print(detail, file=sys.stderr)
        raise SystemExit(5)

    with wave.open(str(normalized), "rb") as wav_file:
        metadata = {
            "duration_ms": int((wav_file.getnframes() * 1000) / wav_file.getframerate())
            if wav_file.getframerate()
            else 0,
            "sample_rate_hz": wav_file.getframerate(),
            "channel_count": wav_file.getnchannels(),
            "codec": codec,
        }
    return normalized, metadata, temp_dir


def ensure_pcm_wav(input_path: Path) -> tuple[Path, dict[str, int | str], Path | None]:
    suffix = input_path.suffix.lower()
    if suffix == ".wav":
        with wave.open(str(input_path), "rb") as wav_file:
            metadata = {
                "duration_ms": int((wav_file.getnframes() * 1000) / wav_file.getframerate())
                if wav_file.getframerate()
                else 0,
                "sample_rate_hz": wav_file.getframerate(),
                "channel_count": wav_file.getnchannels(),
                "codec": "wav",
            }
            if (
                wav_file.getnchannels() == 1
                and wav_file.getsampwidth() == 2
                and wav_file.getcomptype() == "NONE"
            ):
                return input_path, metadata, None
        return normalize_with_ffmpeg(input_path, "wav")

    return normalize_with_ffmpeg(input_path, suffix.removeprefix(".") or "audio")


def recognize_segments(
    wav_path: Path,
    model_path: Path,
    language: str,
) -> list[dict[str, object]]:
    Model, KaldiRecognizer = load_vosk()
    model = Model(str(model_path))
    with wave.open(str(wav_path), "rb") as wav_file:
        recognizer = KaldiRecognizer(model, wav_file.getframerate())
        try:
            recognizer.SetWords(True)
        except Exception:
            pass

        segments: list[dict[str, object]] = []
        segment_id = 1
        while True:
            chunk = wav_file.readframes(4000)
            if not chunk:
                break
            if recognizer.AcceptWaveform(chunk):
                payload = json.loads(recognizer.Result())
                text = str(payload.get("text", "")).strip()
                if not text:
                    continue
                result_words = payload.get("result") or []
                start_ms, end_ms = segment_window(result_words)
                segments.append(
                    {
                        "segment_id": f"seg-{segment_id}",
                        "start_ms": start_ms,
                        "end_ms": end_ms,
                        "text": text,
                        "language": None if language == "auto" else language,
                    }
                )
                segment_id += 1

        final_payload = json.loads(recognizer.FinalResult())
        final_text = str(final_payload.get("text", "")).strip()
        if final_text:
            result_words = final_payload.get("result") or []
            start_ms, end_ms = segment_window(result_words)
            segments.append(
                {
                    "segment_id": f"seg-{segment_id}",
                    "start_ms": start_ms,
                    "end_ms": end_ms,
                    "text": final_text,
                    "language": None if language == "auto" else language,
                }
            )
    return segments


def segment_window(result_words: object) -> tuple[int, int]:
    if isinstance(result_words, list) and result_words:
        first = result_words[0] if isinstance(result_words[0], dict) else {}
        last = result_words[-1] if isinstance(result_words[-1], dict) else {}
        start = int(float(first.get("start", 0.0)) * 1000)
        end = int(float(last.get("end", 0.0)) * 1000)
        return start, max(start, end)
    return 0, 0


def write_payload(
    output_json_path: Path,
    provider_version: str,
    metadata: dict[str, int | str],
    language: str,
    segments: list[dict[str, object]],
) -> None:
    payload = {
        "provider_name": "vosk",
        "provider_version": provider_version,
        "metadata": {
            "duration_ms": metadata.get("duration_ms"),
            "sample_rate_hz": metadata.get("sample_rate_hz"),
            "channel_count": metadata.get("channel_count"),
            "codec": metadata.get("codec"),
            "language": None if language == "auto" else language,
        },
        "segments": segments,
        "diagnostics": [],
    }
    output_json_path.parent.mkdir(parents=True, exist_ok=True)
    output_json_path.write_text(json.dumps(payload, ensure_ascii=True), encoding="utf-8")


def main() -> int:
    input_path, output_json_path, language = parse_args(sys.argv[1:])
    if not input_path.is_file():
        print(f"audio input is missing: {input_path}", file=sys.stderr)
        return 2

    model_path = resolve_model_path()
    wav_path, metadata, cleanup_dir = ensure_pcm_wav(input_path)
    try:
        provider_version = resolve_provider_version()
        segments = recognize_segments(wav_path, model_path, language)
        write_payload(output_json_path, provider_version, metadata, language, segments)
        return 0
    finally:
        if cleanup_dir is not None:
            shutil.rmtree(cleanup_dir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
