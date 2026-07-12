from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

from helpers import write_minimal_config

from envkit.config import ConfigBundle
from envkit.model_sync import (
    MODEL_METADATA_NAME,
    download_archive,
    download_parallel_curl,
    download_segment_count,
    ensure_model,
    model_download_urls,
)
from envkit.utils import EnvError


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


class ModelSyncTests(unittest.TestCase):
    def build_zip_archive(self, root: Path, *, include_required: bool = True) -> Path:
        archive_path = root / "fixtures" / "demo-model.zip"
        archive_path.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive_path, "w") as archive:
            if include_required:
                archive.writestr("demo-model/weights.bin", b"weights")
            archive.writestr("demo-model/config.json", b"{}")
        return archive_path

    def make_bundle(
        self,
        repo_root: Path,
        archive_path: Path,
        *,
        sha256: str,
        required_files: list[str] | None = None,
    ) -> ConfigBundle:
        write_minimal_config(
            repo_root,
            models={
                "models": {
                    "demo-model": {
                        "family": "vosk",
                        "model_id": "demo-model-id",
                        "version": "1.0.0",
                        "archive_type": "zip",
                        "url": archive_path.resolve().as_uri(),
                        "sha256": sha256,
                        "target_dir": "models/demo-model",
                        "archive_root": "demo-model",
                        "required_files": required_files or ["weights.bin", "config.json"],
                    }
                }
            },
        )
        return ConfigBundle(repo_root)

    def test_install_check_and_force_reinstall_model(self) -> None:
        with tempfile.TemporaryDirectory(prefix="markitdown-model-sync-") as tmp:
            repo_root = Path(tmp) / "repo"
            archive_path = self.build_zip_archive(repo_root)
            bundle = self.make_bundle(
                repo_root,
                archive_path,
                sha256=sha256_file(archive_path),
            )

            state = ensure_model(
                bundle=bundle,
                model_key="demo-model",
                check_only=False,
                force=False,
            )
            target_dir = Path(state.target_dir)
            metadata_path = target_dir / MODEL_METADATA_NAME
            self.assertTrue(metadata_path.is_file())

            checked = ensure_model(
                bundle=bundle,
                model_key="demo-model",
                check_only=True,
                force=False,
            )
            self.assertEqual(checked.archive_sha256, state.archive_sha256)

            metadata_path.write_text("MODEL_KEY=drifted\n", encoding="utf-8")
            with self.assertRaises(EnvError):
                ensure_model(
                    bundle=bundle,
                    model_key="demo-model",
                    check_only=True,
                    force=False,
                )

            reinstalled = ensure_model(
                bundle=bundle,
                model_key="demo-model",
                check_only=False,
                force=True,
            )
            self.assertEqual(reinstalled.archive_sha256, state.archive_sha256)

    def test_checksum_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="markitdown-model-sync-") as tmp:
            repo_root = Path(tmp) / "repo"
            archive_path = self.build_zip_archive(repo_root)
            bundle = self.make_bundle(repo_root, archive_path, sha256="0" * 64)
            with self.assertRaises(EnvError):
                ensure_model(
                    bundle=bundle,
                    model_key="demo-model",
                    check_only=False,
                    force=False,
                )

    def test_missing_required_files_fail_install_validation(self) -> None:
        with tempfile.TemporaryDirectory(prefix="markitdown-model-sync-") as tmp:
            repo_root = Path(tmp) / "repo"
            archive_path = self.build_zip_archive(repo_root, include_required=False)
            bundle = self.make_bundle(
                repo_root,
                archive_path,
                sha256=sha256_file(archive_path),
                required_files=["weights.bin", "config.json"],
            )
            with self.assertRaises(EnvError):
                ensure_model(
                    bundle=bundle,
                    model_key="demo-model",
                    check_only=False,
                    force=False,
                )

    def test_stable_partial_archive_is_resumed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="markitdown-model-sync-") as tmp:
            repo_root = Path(tmp) / "repo"
            archive_path = self.build_zip_archive(repo_root)
            bundle = self.make_bundle(
                repo_root,
                archive_path,
                sha256=sha256_file(archive_path),
            )
            cache_dir = repo_root / "env" / "downloads" / "models" / "demo-model"
            cache_dir.mkdir(parents=True)
            partial = cache_dir / ".demo-model.zip.part"
            partial.write_bytes(archive_path.read_bytes()[:16])

            downloaded = download_archive(repo_root / "env", bundle.model("demo-model"))

            self.assertEqual(downloaded.read_bytes(), archive_path.read_bytes())
            self.assertFalse(partial.exists())

    def test_interrupted_download_keeps_stable_partial(self) -> None:
        with tempfile.TemporaryDirectory(prefix="markitdown-model-sync-") as tmp:
            repo_root = Path(tmp) / "repo"
            archive_path = self.build_zip_archive(repo_root)
            bundle = self.make_bundle(
                repo_root,
                archive_path,
                sha256=sha256_file(archive_path),
            )

            def interrupt(argv: list[str], **_kwargs: object) -> None:
                output = Path(argv[argv.index("--output") + 1])
                output.write_bytes(b"partial")
                raise KeyboardInterrupt

            with (
                mock.patch("envkit.model_sync.shutil.which", return_value="curl"),
                mock.patch("envkit.model_sync.subprocess.run", side_effect=interrupt),
                self.assertRaises(KeyboardInterrupt),
            ):
                download_archive(repo_root / "env", bundle.model("demo-model"))

            partial = (
                repo_root
                / "env"
                / "downloads"
                / "models"
                / "demo-model"
                / ".demo-model.zip.part"
            )
            self.assertEqual(partial.read_bytes(), b"partial")

    def test_mirror_candidates_precede_declared_origin(self) -> None:
        spec = {
            "url": "https://origin.example/models/demo.zip",
            "urls": ["https://fallback.example/demo.zip"],
        }
        with mock.patch.dict(
            os.environ,
            {"MARKITDOWN_MODEL_MIRROR_BASE_URLS": "https://mirror-a, https://mirror-b/"},
        ):
            self.assertEqual(
                model_download_urls(spec),
                [
                    "https://mirror-a/demo.zip",
                    "https://mirror-b/demo.zip",
                    "https://fallback.example/demo.zip",
                    "https://origin.example/models/demo.zip",
                ],
            )

    def test_download_segment_count_is_bounded_and_validated(self) -> None:
        with mock.patch.dict(os.environ, {"MARKITDOWN_DOWNLOAD_SEGMENTS": "99"}):
            self.assertEqual(download_segment_count(), 8)
        with mock.patch.dict(os.environ, {"MARKITDOWN_DOWNLOAD_SEGMENTS": "0"}):
            self.assertEqual(download_segment_count(), 1)
        with (
            mock.patch.dict(os.environ, {"MARKITDOWN_DOWNLOAD_SEGMENTS": "many"}),
            self.assertRaises(EnvError),
        ):
            download_segment_count()

    def test_parallel_download_resumes_each_segment(self) -> None:
        payload = b"0123456789abcdefghij"
        with tempfile.TemporaryDirectory(prefix="markitdown-model-sync-") as tmp:
            temporary = Path(tmp) / ".demo.zip.part"
            first_segment = Path(tmp) / ".demo.zip.part.0"
            first_segment.write_bytes(payload[:2])
            requested_ranges: list[str] = []

            def write_range(argv: list[str], **kwargs: object) -> subprocess.CompletedProcess:
                value = argv[argv.index("--range") + 1]
                requested_ranges.append(value)
                start, end = (int(item) for item in value.split("-", 1))
                output = kwargs["stdout"]
                output.write(payload[start : end + 1])
                return subprocess.CompletedProcess(argv, 0)

            with mock.patch(
                "envkit.model_sync.subprocess.run",
                side_effect=write_range,
            ):
                segment_paths = download_parallel_curl(
                    "curl",
                    "https://example.test/demo.zip",
                    temporary,
                    len(payload),
                    4,
                )

            self.assertEqual(temporary.read_bytes(), payload)
            self.assertIn("2-4", requested_ranges)
            self.assertEqual(len(segment_paths), 4)


if __name__ == "__main__":
    unittest.main()
