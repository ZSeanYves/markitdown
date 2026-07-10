from __future__ import annotations

import os
import shutil
from dataclasses import dataclass
from pathlib import Path

from .config import ConfigBundle, PlatformInfo
from .utils import (
    EnvError,
    ensure_dir,
    first_line_from_command,
    generated_env_root,
    is_executable,
    run,
    sha256_file,
    stable_json_dumps,
    write_text_if_changed,
)


@dataclass(frozen=True)
class ToolState:
    name: str
    manager: str
    packages: list[str]
    command_name: str
    command_path: str
    version: str
    version_line: str
    version_args: list[str]
    version_fragment: str
    binary_sha256: str
    record_path: str
    symlink_path: str
    metadata_path: str


class PackageManagerSession:
    def __init__(
        self,
        bundle: ConfigBundle,
        platform: PlatformInfo,
        *,
        no_sudo: bool,
        check_only: bool,
    ) -> None:
        self.bundle = bundle
        self.platform = platform
        self.no_sudo = no_sudo
        self.check_only = check_only
        self._apt_updated = False

    def ensure_tool(self, tool_name: str) -> ToolState:
        spec = self.bundle.tool(tool_name, self.platform.key)
        if not self.check_only:
            self._ensure_packages(spec["packages"], spec["manager"])
        command_path = shutil.which(spec["command"])
        if not command_path:
            raise EnvError(
                f"missing managed command after install/check: {spec['command']}"
            )
        version_line = first_line_from_command([command_path, *spec["version_args"]])
        if spec["version_fragment"] not in version_line:
            raise EnvError(
                f"unexpected {tool_name} version output: {version_line!r}; "
                f"expected fragment {spec['version_fragment']!r}"
            )
        state = self._build_state(tool_name, spec, Path(command_path), version_line)
        if self.check_only:
            self._assert_tool_artifacts(state)
        else:
            self._write_tool_artifacts(state)
        return state

    def _ensure_packages(self, packages: list[str], manager: str) -> None:
        if manager == "apt":
            missing = [pkg for pkg in packages if run(["dpkg", "-s", pkg], check=False).returncode != 0]
            if missing:
                self._ensure_apt_updated()
                self._run_as_root(["apt-get", "install", "-y", *missing])
            return
        if manager == "brew":
            missing = [pkg for pkg in packages if run(["brew", "list", "--versions", pkg], check=False).returncode != 0]
            if missing:
                run(["brew", "install", *missing])
            return
        raise EnvError(f"unsupported package manager: {manager}")

    def _ensure_apt_updated(self) -> None:
        if self._apt_updated:
            return
        self._run_as_root(["apt-get", "update"])
        self._apt_updated = True

    def _run_as_root(self, argv: list[str]) -> None:
        if os.geteuid() == 0:
            run(argv)
            return
        if self.no_sudo:
            raise EnvError(
                f"root privileges are required to run {argv[0]!r}; retry without --no-sudo"
            )
        if not shutil.which("sudo"):
            raise EnvError(f"sudo is required to run: {' '.join(argv)}")
        run(["sudo", *argv])

    def _build_state(
        self,
        tool_name: str,
        spec: dict,
        command_path: Path,
        version_line: str,
    ) -> ToolState:
        env_root = generated_env_root(self.bundle.repo_root)
        symlink_path = (
            env_root
            / "managed-tools"
            / tool_name
            / self.platform.key
            / spec["version"]
            / "bin"
            / spec["command"]
        )
        record_path = env_root / "managed-paths" / tool_name
        metadata_path = env_root / "managed-metadata" / "tools" / f"{tool_name}.json"
        return ToolState(
            name=tool_name,
            manager=spec["manager"],
            packages=list(spec["packages"]),
            command_name=spec["command"],
            command_path=str(command_path.resolve()),
            version=spec["version"],
            version_line=version_line,
            version_args=list(spec["version_args"]),
            version_fragment=spec["version_fragment"],
            binary_sha256=sha256_file(command_path),
            record_path=str(record_path),
            symlink_path=str(symlink_path),
            metadata_path=str(metadata_path),
        )

    def _write_tool_artifacts(self, state: ToolState) -> None:
        symlink_path = Path(state.symlink_path)
        ensure_dir(symlink_path.parent)
        if symlink_path.exists() or symlink_path.is_symlink():
            symlink_path.unlink()
        symlink_path.symlink_to(Path(state.command_path))
        write_text_if_changed(Path(state.record_path), state.symlink_path + "\n")
        write_text_if_changed(
            Path(state.metadata_path),
            stable_json_dumps(self._metadata_payload(state)),
        )

    def _assert_tool_artifacts(self, state: ToolState) -> None:
        symlink_path = Path(state.symlink_path)
        record_path = Path(state.record_path)
        metadata_path = Path(state.metadata_path)
        if not symlink_path.is_symlink():
            raise EnvError(f"missing managed tool symlink: {symlink_path}")
        if str(symlink_path.resolve()) != state.command_path:
            raise EnvError(f"managed tool symlink drift detected: {symlink_path}")
        if not record_path.is_file():
            raise EnvError(f"missing managed path record: {record_path}")
        if record_path.read_text(encoding="utf-8").strip() != state.symlink_path:
            raise EnvError(f"managed path record drift detected: {record_path}")
        if not metadata_path.is_file():
            raise EnvError(f"missing managed tool metadata: {metadata_path}")
        expected_metadata = stable_json_dumps(self._metadata_payload(state))
        if metadata_path.read_text(encoding="utf-8") != expected_metadata:
            raise EnvError(f"managed tool metadata drift detected: {metadata_path}")

    def _metadata_payload(self, state: ToolState) -> dict[str, object]:
        return {
            "binary_sha256": state.binary_sha256,
            "command_name": state.command_name,
            "command_path": state.command_path,
            "manager": state.manager,
            "packages": state.packages,
            "record_path": state.record_path,
            "symlink_path": state.symlink_path,
            "tool_name": state.name,
            "version": state.version,
            "version_args": state.version_args,
            "version_fragment": state.version_fragment,
            "version_line": state.version_line,
        }
