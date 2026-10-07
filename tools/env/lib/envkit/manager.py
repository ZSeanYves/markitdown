from __future__ import annotations

import argparse
import fcntl
import shutil
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from .config import ConfigBundle, detect_platform_key
from .fingerprint import (
    BENCH_ENV,
    profile_fingerprint,
    render_env_file,
    render_fingerprint,
    write_env_file,
    write_fingerprint,
)
from .package_manager import PackageManagerSession, ToolState
from .utils import EnvError, generated_env_root
from .venv_sync import VenvState, ensure_venv_from_lock


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage the optional benchmark comparison environment"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    install = subparsers.add_parser(
        "install", description="Install or check the benchmark baseline"
    )
    install.add_argument("--profile", required=True, choices=["bench"])
    install.add_argument("--check", action="store_true")
    install.add_argument("--force", action="store_true")
    install.add_argument("--python", dest="python_bin")
    install.add_argument("--no-sudo", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        bundle = ConfigBundle()
        with environment_lock(generated_env_root(bundle.repo_root)):
            install_profile(args, bundle=bundle)
            return 0
    except EnvError as exc:
        print(f"[deps] error: {exc}")
        return 1


@contextmanager
def environment_lock(env_root: Path) -> Iterator[None]:
    env_root.mkdir(parents=True, exist_ok=True)
    lock_path = env_root / ".install.lock"
    with lock_path.open("a+", encoding="utf-8") as handle:
        print(f"[deps] waiting for environment lock: {lock_path}", flush=True)
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        print(f"[deps] acquired environment lock: {lock_path}", flush=True)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def install_profile(
    args: argparse.Namespace,
    *,
    bundle: ConfigBundle | None = None,
) -> None:
    if args.profile != "bench":
        raise EnvError(f"unsupported environment profile: {args.profile}")
    bundle = bundle or ConfigBundle()
    profile = bundle.profile("bench")
    platform = detect_platform_key(bundle)
    env_root = generated_env_root(bundle.repo_root)
    env_root.mkdir(parents=True, exist_ok=True)
    action = "checking" if args.check else "installing"
    print(f"[deps] {action} benchmark baseline", flush=True)

    # The benchmark profile has no product runtime tools. Keep this loop so a
    # future build-only profile can add an explicitly reviewed system tool
    # without reintroducing product runtime wiring.
    package_session = PackageManagerSession(
        bundle,
        platform,
        no_sudo=args.no_sudo,
        check_only=args.check,
    )
    tool_states: dict[str, ToolState] = {}
    for tool_name in profile["system_tools"]:
        tool_states[tool_name] = package_session.ensure_tool(tool_name)

    python_bin = resolve_requested_python(args.python_bin)
    venv_state = ensure_venv_from_lock(
        venv_path=env_root / profile["venv_name"],
        lock_path=bundle.config_root / profile["python_lock"],
        requested_python=python_bin,
        check_only=args.check,
        force=args.force,
        expected_python_version=profile.get("python_version"),
        python_requires=profile.get("python_requires"),
    )
    markitdown_bin = Path(venv_state.venv_path) / "bin" / "markitdown"
    if not markitdown_bin.is_file():
        raise EnvError(f"markitdown binary missing after bench install: {markitdown_bin}")

    exports = {
        "MARKITDOWN_MODULE_ROOT": str(bundle.repo_root),
        "MARKITDOWN_BASELINE_VENV": venv_state.venv_path,
        "MARKITDOWN_BASELINE_PYTHON": venv_state.python_path,
        "MARKITDOWN_BIN": str(markitdown_bin),
    }
    env_path = env_root / profile["env_file"]
    fingerprint_path = env_root / "fingerprints" / profile["fingerprint_file"]
    fingerprint_payload = profile_fingerprint(
        bundle=bundle,
        profile_name="bench",
        platform=platform,
        tools=tool_states,
        venv=venv_state,
    )

    if args.check:
        assert_expected_file(env_path, render_env_file(exports, BENCH_ENV), "managed env file")
        assert_expected_file(
            fingerprint_path,
            render_fingerprint(fingerprint_payload),
            "managed fingerprint",
        )
    else:
        write_env_file(env_path, exports, BENCH_ENV)
        write_fingerprint(fingerprint_path, fingerprint_payload)
        print_ready_message("bench", env_path, fingerprint_path, venv_state, tool_states)


def resolve_requested_python(explicit_python: str | None) -> str:
    if explicit_python:
        python_path = Path(explicit_python)
        if not python_path.is_file():
            raise EnvError(f"requested python is unavailable: {explicit_python}")
        return str(python_path)
    python_path = shutil.which("python3") or shutil.which("python")
    if not python_path:
        raise EnvError("python3 is required to build the benchmark environment")
    return python_path


def assert_expected_file(path: Path, expected_text: str, label: str) -> None:
    if not path.is_file():
        raise EnvError(f"missing {label}: {path}")
    actual_text = path.read_text(encoding="utf-8")
    if actual_text != expected_text:
        raise EnvError(f"{label} drift detected: {path}")


def print_ready_message(
    profile_name: str,
    env_path: Path,
    fingerprint_path: Path,
    venv_state: VenvState,
    tool_states: dict[str, ToolState],
) -> None:
    print(f"[deps] {profile_name} benchmark environment is ready.")
    for tool_name, tool_state in sorted(tool_states.items()):
        print(f"[deps] {tool_name}: {tool_state.symlink_path}")
    print(f"[deps] repo-local virtualenv: {venv_state.venv_path}")
    print(f"[deps] repo-local python: {venv_state.python_path}")
    print(f"[deps] env file written to: {env_path}")
    print(f"[deps] fingerprint written to: {fingerprint_path}")
