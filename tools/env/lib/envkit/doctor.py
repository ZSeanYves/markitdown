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
