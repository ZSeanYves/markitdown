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

MODULE_ROOT = Path(
    os.environ.get("MARKITDOWN_MODULE_ROOT", Path(__file__).resolve().parents[3])
)
LIB_ROOT = MODULE_ROOT / "tools" / "env" / "lib"
if str(LIB_ROOT) not in sys.path:
    sys.path.insert(0, str(LIB_ROOT))

from envkit.runtime_contract import (  # noqa: E402
    MODEL_METADATA_NAME,
    ffmpeg_normalize_args,
    stable_env,
)

DEFAULT_MODEL_PATH = MODULE_ROOT / "env" / "models" / "vosk" / "model"
MODEL_REQUIRED_FILES = ("am/final.mdl", "conf/model.conf")
REQUIRED_RUNTIME_ENV = stable_env(str(MODULE_ROOT))
FFMPEG_NORMALIZE_ARGS = ffmpeg_normalize_args(str(MODULE_ROOT))


def usage() -> str:
    return "usage: audio_transcribe_wrapper.py --request-json <request_json_path> --result-json <result_json_path>"


def parse_args(argv: list[str]) -> tuple[Path, Path]:
    if not argv or "--help" in argv or "-h" in argv:
        print(usage())
        raise SystemExit(0)

    request_json_path: Path | None = None
    result_json_path: Path | None = None
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--request-json" and index + 1 < len(argv):
            request_json_path = Path(argv[index + 1])
            index += 2
            continue
        if arg == "--result-json" and index + 1 < len(argv):
            result_json_path = Path(argv[index + 1])
            index += 2
            continue
        print(f"unexpected argument: {arg}", file=sys.stderr)
        raise SystemExit(2)

    if request_json_path is None or result_json_path is None:
        print(usage(), file=sys.stderr)
        raise SystemExit(2)

    return request_json_path, result_json_path


def load_request(request_json_path: Path) -> dict[str, object]:
    try:
        payload = json.loads(request_json_path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"audio request JSON is unreadable: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc

    if not isinstance(payload, dict):
        print("audio request JSON root must be an object.", file=sys.stderr)
        raise SystemExit(2)
    if payload.get("provider") not in (None, "vosk"):
        print("audio request provider must be `vosk`.", file=sys.stderr)
        raise SystemExit(2)
    if payload.get("version") not in (None, "v2"):
        print("audio request version must be `v2`.", file=sys.stderr)
        raise SystemExit(2)
    output_mode = str(payload.get("output_mode", "transcript_json")).strip()
    if output_mode and output_mode != "transcript_json":
        print(f"unsupported audio output_mode: {output_mode}", file=sys.stderr)
        raise SystemExit(2)
    return payload


def normalized_language(raw: object) -> str:
    text = str(raw or "").strip().lower()
    return text or "auto"


def require_stable_runtime_env() -> list[str]:
    diagnostics = []
    for key, expected in REQUIRED_RUNTIME_ENV.items():
        os.environ[key] = expected
        value = expected
        diagnostics.append(f"{key}={value}")
    return diagnostics


def load_metadata(path: Path) -> dict[str, str]:
    if not path.is_file():
        print(f"audio model metadata is missing: {path}", file=sys.stderr)
        raise SystemExit(4)
    metadata: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        metadata[key] = value
    return metadata


def resolve_model_path(request_model_path: object) -> Path:
    raw = str(request_model_path or "").strip()
    if not raw:
        raw = os.environ.get("MARKITDOWN_AUDIO_MODEL_PATH", "").strip()
    model_path = Path(raw) if raw else DEFAULT_MODEL_PATH
    if model_path.is_dir():
        metadata = load_metadata(model_path / MODEL_METADATA_NAME)
        if metadata.get("MODEL_FAMILY") != "vosk":
            print(f"audio model metadata does not describe a Vosk model: {model_path}", file=sys.stderr)
            raise SystemExit(4)
        for required_name in MODEL_REQUIRED_FILES:
            if not (model_path / required_name).is_file():
                print(
                    f"audio model directory is missing required file `{required_name}`: {model_path}",
                    file=sys.stderr,
                )
                raise SystemExit(4)
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
            "Vosk Python package is unavailable. Run `./tools/env/optional_deps.sh install audio` or install "
            "`vosk` into the repo-managed virtualenv used by this wrapper. "
            f"detail: {exc}",
            file=sys.stderr,
        )
        raise SystemExit(3)
    return Model, KaldiRecognizer


def resolve_ffmpeg() -> str:
    managed_record = (
        Path(os.environ.get("MARKITDOWN_MODULE_ROOT", MODULE_ROOT))
        / "env"
        / "managed-paths"
        / "ffmpeg"
    )
    if managed_record.is_file():
        managed_path = managed_record.read_text(encoding="utf-8").strip()
        if managed_path and Path(managed_path).is_file():
            return managed_path
    explicit = os.environ.get("MARKITDOWN_FFMPEG_BIN", "").strip()
    if explicit and Path(explicit).is_file():
        return explicit
    fallback = shutil.which("ffmpeg")
    if fallback:
        return fallback
    print(
        "ffmpeg is required to normalize compressed audio for the local Vosk backend.",
        file=sys.stderr,
    )
    raise SystemExit(5)


def normalize_with_ffmpeg(input_path: Path, codec: str) -> tuple[Path, dict[str, int | str], Path]:
    ffmpeg = resolve_ffmpeg()
    temp_dir = Path(tempfile.mkdtemp(prefix="markitdown-vosk-"))
    normalized = temp_dir / "normalized.wav"
    cmd = [
        ffmpeg,
        "-y",
        "-i",
        str(input_path),
        *FFMPEG_NORMALIZE_ARGS,
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


def reported_codec(input_path: Path) -> str:
    suffix = input_path.suffix.lower().removeprefix(".")
    return suffix or "audio"


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
    diagnostics: list[str],
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
        "diagnostics": diagnostics,
    }
    output_json_path.parent.mkdir(parents=True, exist_ok=True)
    output_json_path.write_text(json.dumps(payload, ensure_ascii=True), encoding="utf-8")


def main() -> int:
    request_json_path, output_json_path = parse_args(sys.argv[1:])
    runtime_diagnostics = require_stable_runtime_env()
    request = load_request(request_json_path)
    input_path = Path(str(request.get("input_audio_path", "")))
    normalized_audio_path_raw = str(request.get("normalized_audio_path", "") or "").strip()
    backend_input_path = Path(normalized_audio_path_raw) if normalized_audio_path_raw else input_path
    language = normalized_language(request.get("language"))
    if not input_path.is_file():
        print(f"audio input is missing: {input_path}", file=sys.stderr)
        return 2
    if not backend_input_path.is_file():
        print(f"audio backend input is missing: {backend_input_path}", file=sys.stderr)
        return 2

    model_path = resolve_model_path(request.get("model_path"))
    wav_path, metadata, cleanup_dir = ensure_pcm_wav(backend_input_path)
    try:
        metadata["codec"] = reported_codec(input_path)
        provider_version = resolve_provider_version()
        segments = recognize_segments(wav_path, model_path, language)
        model_metadata = load_metadata(model_path / MODEL_METADATA_NAME)
        diagnostics = [
            "wrapper=tools/env/wrappers/audio_transcribe_wrapper.py",
            f"model_id={model_metadata.get('MODEL_ID', '')}",
            f"model_archive_sha256={model_metadata.get('ARCHIVE_SHA256', '')}",
            f"model_path={model_path}",
            f"ffmpeg={resolve_ffmpeg()}",
            f"ffmpeg_args={' '.join(FFMPEG_NORMALIZE_ARGS)}",
        ]
        diagnostics.extend(runtime_diagnostics)
        write_payload(
            output_json_path,
            provider_version,
            metadata,
            language,
            segments,
            diagnostics,
        )
        return 0
    finally:
        if cleanup_dir is not None:
            shutil.rmtree(cleanup_dir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
