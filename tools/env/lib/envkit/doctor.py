from __future__ import annotations

from pathlib import Path

from .utils import EnvError, lower_locale_names, run


def require_en_us_utf8_locale() -> None:
    completed = run(["locale", "-a"])
    locales = lower_locale_names(completed.stdout.splitlines())
    if "en_us.utf-8" in locales or "en_us.utf8" in locales:
        return
    raise EnvError("required locale is unavailable: en_US.UTF-8")


def assert_expected_file(path: Path, expected_text: str, label: str) -> None:
    if not path.is_file():
        raise EnvError(f"missing {label}: {path}")
    actual_text = path.read_text(encoding="utf-8")
    if actual_text != expected_text:
        raise EnvError(f"{label} drift detected: {path}")


def assert_runtime_contracts(repo_root: Path, runtime_args: dict) -> None:
    audio_source = (repo_root / "formats" / "audio" / "runtime.mbt").read_text(
        encoding="utf-8"
    )
    ffmpeg_args = runtime_args["commands"]["ffmpeg"]
    ffmpeg_fragment = ", ".join(f'"{item}"' for item in ffmpeg_args)
    if ffmpeg_fragment not in audio_source:
        raise EnvError("ffmpeg runtime args drift detected in formats/audio/runtime.mbt")

    pdftoppm_source = (repo_root / "formats" / "pdf" / "ocr_runtime.mbt").read_text(
        encoding="utf-8"
    )
    pdftoppm_args = runtime_args["commands"]["pdftoppm"]
    pdftoppm_fragment = ", ".join(f'"{item}"' for item in pdftoppm_args)
    if pdftoppm_fragment not in pdftoppm_source:
        raise EnvError("pdftoppm runtime args drift detected in formats/pdf/ocr_runtime.mbt")

    tesseract_source = (repo_root / "formats" / "ocr" / "tesseract.mbt").read_text(
        encoding="utf-8"
    )
    tesseract_args = runtime_args["commands"]["tesseract"]
    tesseract_fragment = ", ".join(f'"{item}"' for item in tesseract_args)
    if tesseract_fragment not in tesseract_source:
        raise EnvError("tesseract runtime args drift detected in formats/ocr/tesseract.mbt")
