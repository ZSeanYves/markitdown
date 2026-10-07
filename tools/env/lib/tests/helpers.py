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
) -> None:
    config_root = repo_root / "tools" / "env" / "config"
    write_json(
        config_root / "profiles.json",
        profiles
        or {
            "profiles": {
                "bench": {
                    "env_file": "bench.env.sh",
                    "fingerprint_file": "bench.json",
                    "venv_name": None,
                    "python_lock": None,
                    "python_version": None,
                    "system_tools": [],
                }
            }
        },
    )
    write_json(
        config_root / "system_tools.json",
        system_tools or {"platforms": {}, "tools": {}},
    )


def env_with_path(prepend: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["PATH"] = f"{prepend}{os.pathsep}{env.get('PATH', '')}"
    return env
