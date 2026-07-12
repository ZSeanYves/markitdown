from __future__ import annotations

import os
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
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
    temporary = archive_path.with_name(f".{archive_path.name}.part")
    urls = model_download_urls(spec)
    errors: list[str] = []
    for url in urls:
        resumed = temporary.stat().st_size if temporary.is_file() else 0
        detail = f" (resuming at {resumed} bytes)" if resumed else ""
        print(f"[deps] downloading model {spec['key']} from {url}{detail}", flush=True)
        try:
            curl = shutil.which("curl")
            segment_paths: list[Path] = []
            if curl:
                segment_paths = download_with_curl(curl, url, temporary)
            else:
                download_with_urllib(url, temporary)
            if sha256_file(temporary) != spec["sha256"]:
                temporary.unlink(missing_ok=True)
                for path in segment_paths:
                    path.unlink(missing_ok=True)
                raise EnvError(f"checksum mismatch for model archive: {url}")
            os.replace(temporary, archive_path)
            for path in segment_paths:
                path.unlink(missing_ok=True)
            return archive_path
        except EnvError as exc:
            errors.append(str(exc))
    raise EnvError("model download failed from every candidate:\n" + "\n".join(errors))


def model_download_urls(spec: dict) -> list[str]:
    archive_name = Path(spec["url"]).name
    urls: list[str] = []
    mirror_bases = os.environ.get("MARKITDOWN_MODEL_MIRROR_BASE_URLS", "")
    for base in mirror_bases.split(","):
        if base.strip():
            urls.append(base.strip().rstrip("/") + "/" + archive_name)
    urls.extend(str(url) for url in spec.get("urls", []))
    urls.append(spec["url"])
    return list(dict.fromkeys(urls))


def download_with_curl(curl: str, url: str, temporary: Path) -> list[Path]:
    range_info = remote_range_info(url)
    segments = download_segment_count()
    if range_info is not None and segments > 1 and range_info >= 8 * 1024 * 1024:
        return download_parallel_curl(curl, url, temporary, range_info, segments)
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
            "--continue-at",
            "-",
            "--progress-bar",
            "--output",
            str(temporary),
            url,
        ],
        check=False,
    )
    if completed.returncode != 0:
        raise EnvError(f"model download failed ({completed.returncode}): {url}")
    return []


def remote_range_info(url: str) -> int | None:
    if not url.startswith(("http://", "https://")):
        return None
    try:
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request, timeout=20) as response:
            if response.headers.get("Accept-Ranges", "").lower() != "bytes":
                return None
            total = int(response.headers.get("Content-Length", "0") or 0)
            return total if total > 0 else None
    except (OSError, ValueError):
        return None


def download_segment_count() -> int:
    raw = os.environ.get("MARKITDOWN_DOWNLOAD_SEGMENTS", "4")
    try:
        return max(1, min(8, int(raw)))
    except ValueError:
        raise EnvError(f"invalid MARKITDOWN_DOWNLOAD_SEGMENTS: {raw}") from None


def download_parallel_curl(
    curl: str,
    url: str,
    temporary: Path,
    total: int,
    segment_count: int,
) -> list[Path]:
    segment_size = (total + segment_count - 1) // segment_count
    segments: list[tuple[Path, int, int]] = []
    for index in range(segment_count):
        start = index * segment_size
        end = min(total - 1, start + segment_size - 1)
        if start > end:
            break
        segments.append((temporary.with_name(f"{temporary.name}.{index}"), start, end))
    print(
        f"[deps] parallel download: {len(segments)} segments, {total} bytes",
        flush=True,
    )
    with ThreadPoolExecutor(max_workers=len(segments)) as executor:
        futures = {
            executor.submit(download_curl_segment, curl, url, path, start, end): index
            for index, (path, start, end) in enumerate(segments)
        }
        for future in as_completed(futures):
            future.result()
            print(
                f"[deps] model segment {futures[future] + 1}/{len(segments)} ready",
                flush=True,
            )
    with temporary.open("wb") as output:
        for path, _, _ in segments:
            with path.open("rb") as source:
                shutil.copyfileobj(source, output, length=1024 * 1024)
    if temporary.stat().st_size != total:
        raise EnvError(
            f"parallel model download size mismatch: expected {total}, got {temporary.stat().st_size}"
        )
    return [path for path, _, _ in segments]


def download_curl_segment(
    curl: str,
    url: str,
    path: Path,
    start: int,
    end: int,
) -> None:
    expected = end - start + 1
    current = path.stat().st_size if path.is_file() else 0
    if current > expected:
        path.unlink()
        current = 0
    if current == expected:
        return
    with path.open("ab") as output:
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
                "--silent",
                "--show-error",
                "--range",
                f"{start + current}-{end}",
                url,
            ],
            stdout=output,
            check=False,
        )
    actual = path.stat().st_size
    if completed.returncode != 0 or actual != expected:
        raise EnvError(
            f"model segment download failed ({completed.returncode}, {actual}/{expected} bytes): {url}"
        )


def download_with_urllib(url: str, temporary: Path) -> None:
    current = temporary.stat().st_size if temporary.is_file() else 0
    request = urllib.request.Request(
        url,
        headers={"Range": f"bytes={current}-"} if current else {},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        resumed = current > 0 and response.headers.get("Content-Range") is not None
        mode = "ab" if resumed else "wb"
        with temporary.open(mode) as handle:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                handle.write(chunk)


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
