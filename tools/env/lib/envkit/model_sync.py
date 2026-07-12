from __future__ import annotations

import os
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path

from .config import ConfigBundle
from .utils import (
    EnvError,
    ensure_dir,
    generated_env_root,
    read_key_value_metadata,
    remove_path,
    sha256_file,
    write_key_value_metadata,
)


MODEL_METADATA_NAME = ".markitdown-model.meta"


@dataclass(frozen=True)
class ModelState:
    key: str
    family: str
    model_id: str
    version: str
    target_dir: str
    metadata_path: str
    archive_sha256: str
    url: str


def ensure_model(
    *,
    bundle: ConfigBundle,
    model_key: str,
    check_only: bool,
    force: bool,
) -> ModelState:
    spec = bundle.model(model_key)
    env_root = generated_env_root(bundle.repo_root)
    target_dir = env_root / spec["target_dir"]
    if model_matches_spec(target_dir, spec):
        if force and not check_only:
            remove_path(target_dir)
        else:
            return build_state(spec, target_dir)

    if check_only:
        raise EnvError(f"managed model is missing or drifted: {target_dir}")
    if target_dir.exists() and not force:
        raise EnvError(
            f"managed model metadata drift detected at {target_dir}; retry with --force"
        )
    if target_dir.exists():
        remove_path(target_dir)

    archive_path = download_archive(env_root, spec)
    install_archive(archive_path, target_dir, spec)
    if not model_matches_spec(target_dir, spec):
        raise EnvError(f"managed model install validation failed: {target_dir}")
    return build_state(spec, target_dir)


def model_matches_spec(target_dir: Path, spec: dict) -> bool:
    if not target_dir.is_dir():
        return False
    metadata_path = target_dir / MODEL_METADATA_NAME
    if not metadata_path.is_file():
        return False
    try:
        metadata = read_key_value_metadata(metadata_path)
    except EnvError:
        return False
    expected = model_metadata(spec, target_dir)
    for key, value in expected.items():
        if metadata.get(key) != value:
            return False
    for required in spec["required_files"]:
        if not (target_dir / required).is_file():
            return False
    return True


def build_state(spec: dict, target_dir: Path) -> ModelState:
    return ModelState(
        key=spec["key"],
        family=spec["family"],
        model_id=spec["model_id"],
        version=spec["version"],
        target_dir=str(target_dir),
        metadata_path=str(target_dir / MODEL_METADATA_NAME),
        archive_sha256=spec["sha256"],
        url=spec["url"],
    )


def download_archive(env_root: Path, spec: dict) -> Path:
    downloads_dir = env_root / "downloads" / "models" / spec["key"]
    ensure_dir(downloads_dir)
    archive_name = Path(spec["url"]).name
    archive_path = downloads_dir / archive_name
    if archive_path.is_file() and sha256_file(archive_path) == spec["sha256"]:
        return archive_path
    temporary = archive_path.with_name(f".{archive_path.name}.part-{os.getpid()}")
    if temporary.exists():
        temporary.unlink()
    print(f"[deps] downloading model {spec['key']} from {spec['url']}", flush=True)
    try:
        curl = shutil.which("curl")
        if curl:
            completed = subprocess.run(
                [
                    curl,
                    "--fail",
                    "--location",
                    "--retry",
                    "3",
                    "--retry-all-errors",
                    "--connect-timeout",
                    "20",
                    "--speed-time",
                    "60",
                    "--speed-limit",
                    "1024",
                    "--progress-bar",
                    "--output",
                    str(temporary),
                    spec["url"],
                ],
                check=False,
            )
            if completed.returncode != 0:
                raise EnvError(
                    f"model download failed ({completed.returncode}): {spec['url']}"
                )
        else:
            with (
                urllib.request.urlopen(spec["url"], timeout=60) as response,
                temporary.open("wb") as handle,
            ):
                total = int(response.headers.get("Content-Length", "0") or 0)
                downloaded = 0
                next_report = 8 * 1024 * 1024
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    handle.write(chunk)
                    downloaded += len(chunk)
                    if downloaded >= next_report:
                        detail = (
                            f"{downloaded * 100 // total}%"
                            if total > 0
                            else f"{downloaded // (1024 * 1024)} MiB"
                        )
                        print(f"[deps] model {spec['key']}: {detail}", flush=True)
                        next_report += 8 * 1024 * 1024
        if sha256_file(temporary) != spec["sha256"]:
            raise EnvError(f"checksum mismatch for model archive: {spec['url']}")
        os.replace(temporary, archive_path)
    finally:
        if temporary.exists():
            temporary.unlink()
    return archive_path


def install_archive(archive_path: Path, target_dir: Path, spec: dict) -> None:
    parent = target_dir.parent
    ensure_dir(parent)
    with tempfile.TemporaryDirectory(prefix="markitdown-model-") as temp_root:
        temp_dir = Path(temp_root)
        extract_dir = temp_dir / "extract"
        ensure_dir(extract_dir)
        archive_type = spec["archive_type"]
        if archive_type == "zip":
            with zipfile.ZipFile(archive_path) as archive:
                archive.extractall(extract_dir)
        elif archive_type == "tar":
            with tarfile.open(archive_path) as archive:
                archive.extractall(extract_dir)
        else:
            raise EnvError(f"unsupported model archive type: {archive_type}")
        extracted_root = extract_dir / spec["archive_root"]
        if not extracted_root.is_dir():
            raise EnvError(
                f"model archive missing expected root directory: {spec['archive_root']}"
            )
        shutil.move(str(extracted_root), str(target_dir))
    write_key_value_metadata(target_dir / MODEL_METADATA_NAME, model_metadata(spec, target_dir))


def model_metadata(spec: dict, target_dir: Path) -> dict[str, str]:
    return {
        "MODEL_FAMILY": spec["family"],
        "MODEL_KEY": spec["key"],
        "MODEL_ID": spec["model_id"],
        "MODEL_VERSION": spec["version"],
        "ARCHIVE_TYPE": spec["archive_type"],
        "ARCHIVE_URL": spec["url"],
        "ARCHIVE_SHA256": spec["sha256"],
        "TARGET_DIR": str(target_dir),
        "ARCHIVE_ROOT": spec["archive_root"],
        "REQUIRED_FILES": ",".join(spec["required_files"]),
    }
