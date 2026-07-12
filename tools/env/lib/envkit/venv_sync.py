from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .utils import EnvError, remove_path, run, sha256_file


BOOTSTRAP_PACKAGES = {"pip", "setuptools", "wheel", "distribute"}


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
    python_requires: str | None = None,
) -> VenvState:
    if check_only:
        return inspect_venv(
            venv_path=venv_path,
            lock_path=lock_path,
            expected_python_version=expected_python_version,
            python_requires=python_requires,
        )

    rebuild = force or not (venv_path / "bin" / "python").is_file()
    if not rebuild:
        try:
            return inspect_venv(
                venv_path=venv_path,
                lock_path=lock_path,
                expected_python_version=expected_python_version,
                python_requires=python_requires,
            )
        except EnvError:
            rebuild = True

    if rebuild:
        assert_python_compatible(requested_python, python_requires)
        remove_path(venv_path)
        run([requested_python, "-m", "venv", str(venv_path)])
        python_path = venv_path / "bin" / "python"
        run([str(python_path), "-m", "pip", "install", "--requirement", str(lock_path)])

    return inspect_venv(
        venv_path=venv_path,
        lock_path=lock_path,
        expected_python_version=expected_python_version,
        python_requires=python_requires,
    )


def inspect_venv(
    *,
    venv_path: Path,
    lock_path: Path,
    expected_python_version: str | None,
    python_requires: str | None = None,
) -> VenvState:
    python_path = venv_path / "bin" / "python"
    if not python_path.is_file():
        raise EnvError(f"missing virtualenv python: {python_path}")
    version_line = run([str(python_path), "--version"]).stdout.strip()
    assert_version_satisfies(version_line, python_requires, str(python_path))
    if expected_python_version:
        expected_prefix = f"Python {expected_python_version}"
        if not version_line.startswith(expected_prefix):
            raise EnvError(
                f"unexpected python version for {venv_path}: {version_line!r}; "
                f"expected {expected_prefix!r}"
            )
    expected_packages = locked_requirements_for_python(lock_path, version_line)
    locked_package_names = {
        frozen_requirement_name(requirement) for requirement in expected_packages
    }
    freeze = run(
        [str(python_path), "-m", "pip", "freeze", "--all"]
    ).stdout.splitlines()
    actual_packages = sorted(
        line.strip()
        for line in freeze
        if line.strip()
        and not is_unlocked_bootstrap_package(line, locked_package_names)
    )
    if actual_packages != expected_packages:
        missing = sorted(set(expected_packages) - set(actual_packages))
        unexpected = sorted(set(actual_packages) - set(expected_packages))
        raise EnvError(
            f"installed Python environment does not match lock: {lock_path}; "
            f"missing={missing!r}; unexpected={unexpected!r}"
        )
    return VenvState(
        venv_path=str(venv_path),
        python_path=str(python_path),
        python_version=version_line,
        lock_path=str(lock_path),
        lock_sha256=sha256_file(lock_path),
        packages=expected_packages,
    )


def assert_python_compatible(python_path: str, python_requires: str | None) -> None:
    version_line = run([python_path, "--version"]).stdout.strip()
    assert_version_satisfies(version_line, python_requires, python_path)


def assert_version_satisfies(
    version_line: str, python_requires: str | None, python_path: str
) -> None:
    if not python_requires:
        return
    try:
        version = tuple(int(part) for part in version_line.removeprefix("Python ").split(".")[:3])
    except ValueError as exc:
        raise EnvError(f"unable to parse Python version from {python_path}: {version_line!r}") from exc
    if len(version) < 2:
        raise EnvError(f"unable to parse Python version from {python_path}: {version_line!r}")
    for constraint in python_requires.split(","):
        constraint = constraint.strip()
        operator = next(
            (candidate for candidate in (">=", "<=", "==", ">", "<") if constraint.startswith(candidate)),
            None,
        )
        if operator is None:
            raise EnvError(f"unsupported Python version constraint: {constraint!r}")
        expected = tuple(int(part) for part in constraint[len(operator) :].split("."))
        actual = version[: len(expected)]
        matches = {
            ">=": actual >= expected,
            "<=": actual <= expected,
            "==": actual == expected,
            ">": actual > expected,
            "<": actual < expected,
        }[operator]
        if not matches:
            raise EnvError(
                f"incompatible Python for managed environment: {version_line!r} at {python_path}; "
                f"required {python_requires}. Pass --python PATH with a compatible interpreter"
            )


def locked_requirements_for_python(lock_path: Path, version_line: str) -> list[str]:
    python_version = tuple(
        int(part) for part in version_line.removeprefix("Python ").split(".")[:2]
    )
    requirements: list[str] = []
    for raw_line in lock_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        requirement, separator, marker = line.partition(";")
        if separator and not python_version_marker_matches(marker.strip(), python_version):
            continue
        requirements.append(requirement.strip())
    return sorted(requirements)


def python_version_marker_matches(marker: str, python_version: tuple[int, ...]) -> bool:
    parts = marker.replace('"', "").replace("'", "").split()
    if len(parts) != 3 or parts[0] != "python_version":
        raise EnvError(f"unsupported Python lock marker: {marker!r}")
    operator, expected_text = parts[1:]
    expected = tuple(int(part) for part in expected_text.split("."))
    matches = {
        ">=": python_version >= expected,
        "<=": python_version <= expected,
        "==": python_version == expected,
        ">": python_version > expected,
        "<": python_version < expected,
    }
    try:
        return matches[operator]
    except KeyError as exc:
        raise EnvError(f"unsupported Python lock marker: {marker!r}") from exc


def is_unlocked_bootstrap_package(
    requirement: str,
    locked_package_names: set[str],
) -> bool:
    package_name = frozen_requirement_name(requirement)
    return (
        package_name in BOOTSTRAP_PACKAGES
        and package_name not in locked_package_names
    )


def frozen_requirement_name(requirement: str) -> str:
    package_name = requirement.strip().split("==", 1)[0].split(" @ ", 1)[0]
    return package_name.casefold().replace("_", "-")
