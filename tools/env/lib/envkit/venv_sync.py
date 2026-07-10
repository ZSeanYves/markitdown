from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .utils import EnvError, remove_path, run, sha256_file


@dataclass(frozen=True)
class VenvState:
    venv_path: str
    python_path: str
    python_version: str
    lock_path: str
    lock_sha256: str
    packages: list[str]


def ensure_venv_from_lock(
    *,
    venv_path: Path,
    lock_path: Path,
    requested_python: str,
    check_only: bool,
    force: bool,
    expected_python_version: str | None,
) -> VenvState:
    if check_only:
        return inspect_venv(
            venv_path=venv_path,
            lock_path=lock_path,
            expected_python_version=expected_python_version,
        )

    rebuild = force or not (venv_path / "bin" / "python").is_file()
    if not rebuild:
        try:
            return inspect_venv(
                venv_path=venv_path,
                lock_path=lock_path,
                expected_python_version=expected_python_version,
            )
        except EnvError:
            rebuild = True

    if rebuild:
        remove_path(venv_path)
        run([requested_python, "-m", "venv", str(venv_path)])
        python_path = venv_path / "bin" / "python"
        run([str(python_path), "-m", "pip", "install", "--requirement", str(lock_path)])

    return inspect_venv(
        venv_path=venv_path,
        lock_path=lock_path,
        expected_python_version=expected_python_version,
    )


def inspect_venv(
    *,
    venv_path: Path,
    lock_path: Path,
    expected_python_version: str | None,
) -> VenvState:
    python_path = venv_path / "bin" / "python"
    if not python_path.is_file():
        raise EnvError(f"missing virtualenv python: {python_path}")
    version_line = run([str(python_path), "--version"]).stdout.strip()
    if expected_python_version:
        expected_prefix = f"Python {expected_python_version}"
        if not version_line.startswith(expected_prefix):
            raise EnvError(
                f"unexpected python version for {venv_path}: {version_line!r}; "
                f"expected {expected_prefix!r}"
            )
    freeze = run([str(python_path), "-m", "pip", "freeze"]).stdout.splitlines()
    actual_packages = sorted(line.strip() for line in freeze if line.strip())
    expected_packages = sorted(
        line.strip() for line in lock_path.read_text(encoding="utf-8").splitlines() if line.strip()
    )
    if actual_packages != expected_packages:
        raise EnvError(
            f"installed Python environment does not match lock: {lock_path}"
        )
    return VenvState(
        venv_path=str(venv_path),
        python_path=str(python_path),
        python_version=version_line,
        lock_path=str(lock_path),
        lock_sha256=sha256_file(lock_path),
        packages=expected_packages,
    )
