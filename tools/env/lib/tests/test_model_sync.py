from __future__ import annotations

import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from helpers import write_minimal_config

from envkit.config import ConfigBundle
from envkit.model_sync import MODEL_METADATA_NAME, ensure_model
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


if __name__ == "__main__":
    unittest.main()
