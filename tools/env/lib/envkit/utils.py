from __future__ import annotations

import hashlib
import json
import os
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Iterable, Sequence


class EnvError(RuntimeError):
    pass


def repo_root() -> Path:
    return Path(__file__).resolve().parents[4]


def config_root(root: Path | None = None) -> Path:
    return (root or repo_root()) / "tools" / "env" / "config"


def generated_env_root(root: Path | None = None) -> Path:
    return (root or repo_root()) / "env"


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise EnvError(f"missing config file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise EnvError(f"invalid JSON in {path}: {exc}") from exc


def run(
    argv: Sequence[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        list(argv),
        cwd=str(cwd) if cwd else None,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    if check and completed.returncode != 0:
        raise EnvError(
            f"command failed ({completed.returncode}): {shlex.join(argv)}\n"
            f"stdout:\n{completed.stdout}\n"
            f"stderr:\n{completed.stderr}"
        )
    return completed


def first_line_from_command(argv: Sequence[str]) -> str:
    completed = run(argv, check=False)
    combined = "\n".join(
        [part for part in (completed.stdout.strip(), completed.stderr.strip()) if part]
    ).strip()
    if not combined:
        raise EnvError(f"command produced no version output: {shlex.join(argv)}")
    return combined.splitlines()[0].strip()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def shell_join(parts: Sequence[str]) -> str:
    return shlex.join(list(parts))


def write_text_if_changed(path: Path, text: str) -> None:
    ensure_dir(path.parent)
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def stable_json_dumps(payload: object) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def lower_locale_names(items: Iterable[str]) -> list[str]:
    return [item.strip().lower() for item in items if item.strip()]


def is_executable(path: Path) -> bool:
    return path.is_file() and os.access(path, os.X_OK)


def write_key_value_metadata(path: Path, mapping: dict[str, str]) -> None:
    lines = [f"{key}={value}" for key, value in mapping.items()]
    write_text_if_changed(path, "\n".join(lines) + "\n")


def read_key_value_metadata(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise EnvError(f"missing metadata file: {path}")
    payload: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        payload[key] = value
    return payload
