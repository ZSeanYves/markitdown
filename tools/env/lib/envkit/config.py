from __future__ import annotations

import platform
from dataclasses import dataclass
from pathlib import Path

from .utils import EnvError, config_root, load_json, repo_root, run


@dataclass(frozen=True)
class PlatformInfo:
    key: str
    os_name: str
    arch: str
    manager: str


class ConfigBundle:
    def __init__(self, root: Path | None = None) -> None:
        self.repo_root = root or repo_root()
        self.config_root = config_root(self.repo_root)
        self.profile_data = load_json(self.config_root / "profiles.json")["profiles"]
        self.system_tools = load_json(self.config_root / "system_tools.json")
        self.models = load_json(self.config_root / "models.json")["models"]
        self.runtime_args = load_json(self.config_root / "runtime_args.json")

    def profile(self, name: str) -> dict:
        try:
            return self.profile_data[name]
        except KeyError as exc:
            raise EnvError(f"unknown env profile: {name}") from exc

    def tool(self, name: str, platform_key: str) -> dict:
        try:
            tool_data = self.system_tools["tools"][name][platform_key]
        except KeyError as exc:
            raise EnvError(
                f"unsupported tool/platform combination: {name} on {platform_key}"
            ) from exc
        return {
            **tool_data,
            "name": name,
            "manager": self.platform(platform_key).manager,
        }

    def platform(self, platform_key: str) -> PlatformInfo:
        try:
            platform_data = self.system_tools["platforms"][platform_key]
        except KeyError as exc:
            raise EnvError(f"unsupported platform key: {platform_key}") from exc
        os_name, arch = split_platform_key(platform_key)
        return PlatformInfo(
            key=platform_key,
            os_name=os_name,
            arch=arch,
            manager=platform_data["manager"],
        )

    def model(self, key: str) -> dict:
        try:
            return {**self.models[key], "key": key}
        except KeyError as exc:
            raise EnvError(f"unknown managed model key: {key}") from exc


def split_platform_key(platform_key: str) -> tuple[str, str]:
    if platform_key.startswith("linux-"):
        _, arch, *_ = platform_key.split("-")
        return ("Linux", arch)
    if platform_key.startswith("darwin-"):
        _, arch, *_ = platform_key.split("-")
        return ("Darwin", arch)
    return ("unknown", "unknown")


def detect_platform_key(bundle: ConfigBundle) -> PlatformInfo:
    os_name = platform.system()
    arch_raw = platform.machine().lower()
    if arch_raw in {"amd64", "x86_64"}:
        arch = "x86_64"
    elif arch_raw in {"arm64", "aarch64"}:
        arch = "arm64"
    else:
        arch = arch_raw

    if os_name == "Linux":
        os_release = Path("/etc/os-release")
        if not os_release.is_file():
            raise EnvError("missing /etc/os-release on Linux runtime")
        payload: dict[str, str] = {}
        for line in os_release.read_text(encoding="utf-8").splitlines():
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            payload[key] = value.strip().strip('"')
        distro = payload.get("ID")
        codename = payload.get("VERSION_CODENAME")
        if not distro or not codename:
            raise EnvError("unable to resolve Linux distro codename from /etc/os-release")
        key = f"linux-{arch}-{distro}-{codename}"
        return bundle.platform(key)

    if os_name == "Darwin":
        completed = run(["sw_vers", "-productVersion"])
        major = completed.stdout.strip().split(".", 1)[0]
        mapping = {
            ("arm64", "14"): "darwin-arm64-sonoma",
            ("arm64", "15"): "darwin-arm64-sequoia",
            ("arm64", "26"): "darwin-arm64-tahoe",
            ("x86_64", "14"): "darwin-x86_64-sonoma",
        }
        try:
            return bundle.platform(mapping[(arch, major)])
        except KeyError as exc:
            raise EnvError(f"unsupported macOS runtime: arch={arch} major={major}") from exc

    raise EnvError(f"unsupported platform: {os_name}")
