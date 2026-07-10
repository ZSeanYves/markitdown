from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from .config import ConfigBundle, detect_platform_key
from .doctor import (
    assert_expected_file,
    assert_runtime_contracts,
    require_en_us_utf8_locale,
)
from .fingerprint import (
    profile_fingerprint,
    render_env_file,
    render_fingerprint,
    write_env_file,
    write_fingerprint,
)
from .model_sync import ensure_model
from .package_manager import PackageManagerSession, ToolState
from .utils import EnvError, generated_env_root, shell_join
from .venv_sync import VenvState, ensure_venv_from_lock


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage markitdown tools/env runtimes")
    subparsers = parser.add_subparsers(dest="command", required=True)

    install = subparsers.add_parser("install", description="Install or check a managed env profile")
    install.add_argument("--profile", required=True, choices=["balance", "audio", "accurate", "bench"])
    install.add_argument("--check", action="store_true")
    install.add_argument("--force", action="store_true")
    install.add_argument("--python", dest="python_bin")
    install.add_argument("--no-sudo", action="store_true")
    install.add_argument("--model")

    sync_model = subparsers.add_parser("sync-model", description="Install or check one managed model")
    sync_model.add_argument("--key", required=True)
    sync_model.add_argument("--check", action="store_true")
    sync_model.add_argument("--force", action="store_true")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "install":
            install_profile(args)
            return 0
        if args.command == "sync-model":
            sync_model(args)
            return 0
    except EnvError as exc:
        print(f"[deps] error: {exc}")
        return 1
    raise AssertionError(f"unreachable command: {args.command}")


def install_profile(args: argparse.Namespace) -> None:
    bundle = ConfigBundle()
    profile = bundle.profile(args.profile)
    platform = detect_platform_key(bundle)
    env_root = generated_env_root(bundle.repo_root)
    env_root.mkdir(parents=True, exist_ok=True)
    require_en_us_utf8_locale()
    assert_runtime_contracts(bundle.repo_root, bundle.runtime_args)

    package_session = PackageManagerSession(
        bundle,
        platform,
        no_sudo=args.no_sudo,
        check_only=args.check,
    )
    tool_states = {
        tool_name: package_session.ensure_tool(tool_name)
        for tool_name in profile["system_tools"]
    }

    venv_state: VenvState | None = None
    if profile["venv_name"] and profile["python_lock"]:
        python_bin = resolve_requested_python(args.python_bin)
        venv_state = ensure_venv_from_lock(
            venv_path=env_root / profile["venv_name"],
            lock_path=bundle.config_root / profile["python_lock"],
            requested_python=python_bin,
            check_only=args.check,
            force=args.force,
            expected_python_version=profile.get("python_version"),
        )

    models = sync_profile_models(bundle, args.profile, profile, args)
    exports = profile_exports(bundle, args.profile, venv_state, tool_states, models)
    env_path = env_root / profile["env_file"]
    fingerprint_path = env_root / "fingerprints" / profile["fingerprint_file"]
    fingerprint_payload = profile_fingerprint(
        bundle=bundle,
        profile_name=args.profile,
        platform=platform,
        tools=tool_states,
        venv=venv_state,
        models=models,
    )

    if args.check:
        assert_expected_file(
            env_path,
            render_env_file(exports, bundle.runtime_args["stable_env"]),
            "managed env file",
        )
        assert_expected_file(
            fingerprint_path,
            render_fingerprint(fingerprint_payload),
            "managed fingerprint",
        )
    else:
        write_env_file(env_path, exports, bundle.runtime_args["stable_env"])
        write_fingerprint(fingerprint_path, fingerprint_payload)
        print_ready_message(args.profile, env_path, fingerprint_path, venv_state, tool_states)


def sync_model(args: argparse.Namespace) -> None:
    bundle = ConfigBundle()
    model_state = ensure_model(
        bundle=bundle,
        model_key=args.key,
        check_only=args.check,
        force=args.force,
    )
    print(model_state.target_dir)


def sync_profile_models(
    bundle: ConfigBundle,
    profile_name: str,
    profile: dict,
    args: argparse.Namespace,
) -> dict[str, dict]:
    results: dict[str, dict] = {}
    if profile_name == "audio":
        binding = profile["models"][0]
        requested_model = args.model or binding["default_key"]
        if requested_model not in binding["allowed_keys"]:
            raise EnvError(
                f"unsupported audio model key: {requested_model}; expected one of {binding['allowed_keys']}"
            )
        state = ensure_model(
            bundle=bundle,
            model_key=requested_model,
            check_only=args.check,
            force=args.force,
        )
        results[binding["binding"]] = {
            "archive_sha256": state.archive_sha256,
            "family": state.family,
            "key": state.key,
            "metadata_path": state.metadata_path,
            "model_id": state.model_id,
            "path": state.target_dir,
            "url": state.url,
            "version": state.version,
        }
        return results

    for binding in profile["models"]:
        state = ensure_model(
            bundle=bundle,
            model_key=binding["key"],
            check_only=args.check,
            force=args.force,
        )
        results[binding["binding"]] = {
            "archive_sha256": state.archive_sha256,
            "family": state.family,
            "key": state.key,
            "metadata_path": state.metadata_path,
            "model_id": state.model_id,
            "path": state.target_dir,
            "url": state.url,
            "version": state.version,
        }
    return results


def profile_exports(
    bundle: ConfigBundle,
    profile_name: str,
    venv_state: VenvState | None,
    tool_states: dict[str, ToolState],
    models: dict[str, dict],
) -> dict[str, str]:
    root = str(bundle.repo_root)
    exports: dict[str, str] = {"MARKITDOWN_MODULE_ROOT": root}
    if profile_name == "balance":
        exports["MARKITDOWN_TESSERACT_BIN"] = tool_states["tesseract"].symlink_path
        exports["MARKITDOWN_PDFTOPPM_BIN"] = tool_states["pdftoppm"].symlink_path
        return exports
    if profile_name == "audio":
        assert venv_state is not None
        ffmpeg_state = tool_states["ffmpeg"]
        audio_model = models["audio_model"]
        wrapper = bundle.repo_root / "tools" / "env" / "wrappers" / "audio_transcribe_wrapper.py"
        exports["MARKITDOWN_RUNTIME_PYTHON"] = venv_state.python_path
        exports["MARKITDOWN_FFMPEG_BIN"] = ffmpeg_state.symlink_path
        exports["MARKITDOWN_AUDIO_CMD"] = shell_join([venv_state.python_path, str(wrapper)])
        exports["MARKITDOWN_AUDIO_MODEL_PATH"] = audio_model["path"]
        exports["MARKITDOWN_AUDIO_MODEL_METADATA_PATH"] = audio_model["metadata_path"]
        return exports
    if profile_name == "accurate":
        assert venv_state is not None
        wrapper = bundle.repo_root / "tools" / "env" / "wrappers" / "paddle_ocr_wrapper.py"
        exports["MARKITDOWN_RUNTIME_PYTHON"] = venv_state.python_path
        exports["MARKITDOWN_TESSERACT_BIN"] = tool_states["tesseract"].symlink_path
        exports["MARKITDOWN_PDFTOPPM_BIN"] = tool_states["pdftoppm"].symlink_path
        exports["MARKITDOWN_PADDLE_OCR_CMD"] = shell_join([venv_state.python_path, str(wrapper)])
        exports["MARKITDOWN_PADDLE_OCR_DEFAULT_DET_MODEL_DIR"] = models["paddle_default_det"]["path"]
        exports["MARKITDOWN_PADDLE_OCR_DEFAULT_REC_MODEL_DIR"] = models["paddle_default_rec"]["path"]
        exports["MARKITDOWN_PADDLE_OCR_KOREAN_DET_MODEL_DIR"] = models["paddle_korean_det"]["path"]
        exports["MARKITDOWN_PADDLE_OCR_KOREAN_REC_MODEL_DIR"] = models["paddle_korean_rec"]["path"]
        return exports
    if profile_name == "bench":
        assert venv_state is not None
        markitdown_bin = Path(venv_state.venv_path) / "bin" / "markitdown"
        if not markitdown_bin.is_file():
            raise EnvError(f"markitdown binary missing after bench install: {markitdown_bin}")
        exports["MARKITDOWN_BASELINE_VENV"] = venv_state.venv_path
        exports["MARKITDOWN_BASELINE_PYTHON"] = venv_state.python_path
        exports["MARKITDOWN_BIN"] = str(markitdown_bin)
        return exports
    raise EnvError(f"unsupported profile exports: {profile_name}")


def resolve_requested_python(explicit_python: str | None) -> str:
    if explicit_python:
        python_path = Path(explicit_python)
        if not python_path.is_file():
            raise EnvError(f"requested python is unavailable: {explicit_python}")
        return str(python_path)
    python_path = shutil.which("python3") or shutil.which("python")
    if not python_path:
        raise EnvError("python3 is required to build managed virtualenvs")
    return python_path


def print_ready_message(
    profile_name: str,
    env_path: Path,
    fingerprint_path: Path,
    venv_state: VenvState | None,
    tool_states: dict[str, ToolState],
) -> None:
    print(f"[deps] {profile_name} dependencies are ready.")
    for tool_name, tool_state in sorted(tool_states.items()):
        print(f"[deps] {tool_name}: {tool_state.symlink_path}")
    if venv_state is not None:
        print(f"[deps] repo-local virtualenv: {venv_state.venv_path}")
        print(f"[deps] repo-local python: {venv_state.python_path}")
    print(f"[deps] env file written to: {env_path}")
    print(f"[deps] fingerprint: {fingerprint_path}")
