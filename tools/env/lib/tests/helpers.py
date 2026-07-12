from __future__ import annotations

import json
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
LIB_ROOT = ROOT / "tools" / "env" / "lib"
if str(LIB_ROOT) not in sys.path:
    sys.path.insert(0, str(LIB_ROOT))


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_executable(path: Path, text: str) -> None:
    write_text(path, text)
    path.chmod(path.stat().st_mode | 0o111)


def write_minimal_config(
    repo_root: Path,
    *,
    profiles: dict | None = None,
    system_tools: dict | None = None,
    models: dict | None = None,
    runtime_args: dict | None = None,
) -> None:
    config_root = repo_root / "tools" / "env" / "config"
    write_json(
        config_root / "profiles.json",
        profiles
        or {
            "profiles": {
                "balance": {
                    "env_file": "balance.env.sh",
                    "fingerprint_file": "balance.json",
                    "venv_name": None,
                    "python_lock": None,
                    "python_version": None,
                    "system_tools": [],
                    "models": [],
                }
            }
        },
    )
    write_json(
        config_root / "system_tools.json",
        system_tools or {"platforms": {}, "tools": {}},
    )
    write_json(config_root / "models.json", models or {"models": {}})
    write_json(
        config_root / "runtime_args.json",
        runtime_args
        or {
            "stable_env": {},
            "commands": {
                "ffmpeg": ["-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le"],
                "pdftoppm": ["-r", "150", "-png"],
                "tesseract": ["--oem", "1", "--psm", "6"],
            },
            "paddle": {
                "env": {"FLAGS_enable_pir_api": "0"},
                "init_kwargs": {
                    "enable_mkldnn": False,
                    "use_doc_orientation_classify": False,
                    "use_doc_unwarping": False,
                    "use_textline_orientation": False,
                },
                "predict_kwargs": {
                    "use_doc_orientation_classify": False,
                    "use_doc_unwarping": False,
                    "use_textline_orientation": False,
                },
            },
        },
    )


def env_with_path(prepend: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["PATH"] = f"{prepend}{os.pathsep}{env.get('PATH', '')}"
    return env
