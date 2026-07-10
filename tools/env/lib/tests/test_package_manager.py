from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from helpers import env_with_path, write_executable, write_minimal_config

from envkit.config import ConfigBundle
from envkit.package_manager import PackageManagerSession
from envkit.utils import EnvError


class PackageManagerTests(unittest.TestCase):
    def make_bundle(self, repo_root: Path) -> tuple[ConfigBundle, object]:
        write_minimal_config(
            repo_root,
            system_tools={
                "platforms": {"linux-x86_64-ubuntu-noble": {"manager": "apt"}},
                "tools": {
                    "ffmpeg": {
                        "linux-x86_64-ubuntu-noble": {
                            "packages": ["ffmpeg"],
                            "command": "ffmpeg",
                            "version": "9.9.9-test",
                            "version_fragment": "ffmpeg version 9.9.9-test",
                            "version_args": ["--version"],
                        }
                    }
                },
            },
        )
        bundle = ConfigBundle(repo_root)
        return bundle, bundle.platform("linux-x86_64-ubuntu-noble")

    def test_install_and_check_managed_tool_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo_root = Path(tmp) / "repo"
            fake_bin = repo_root / "fake-bin"
            write_executable(
                fake_bin / "ffmpeg",
                "#!/bin/sh\necho 'ffmpeg version 9.9.9-test'\n",
            )
            bundle, platform = self.make_bundle(repo_root)
            session = PackageManagerSession(
                bundle,
                platform,
                no_sudo=True,
                check_only=False,
            )
            with mock.patch.dict(os.environ, env_with_path(fake_bin), clear=False):
                with mock.patch.object(session, "_ensure_packages"):
                    state = session.ensure_tool("ffmpeg")

            self.assertTrue(Path(state.symlink_path).is_symlink())
            self.assertTrue(Path(state.record_path).is_file())
            self.assertTrue(Path(state.metadata_path).is_file())

            check_session = PackageManagerSession(
                bundle,
                platform,
                no_sudo=True,
                check_only=True,
            )
            with mock.patch.dict(os.environ, env_with_path(fake_bin), clear=False):
                check_state = check_session.ensure_tool("ffmpeg")
            self.assertEqual(check_state.version, "9.9.9-test")

    def test_version_fragment_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo_root = Path(tmp) / "repo"
            fake_bin = repo_root / "fake-bin"
            write_executable(
                fake_bin / "ffmpeg",
                "#!/bin/sh\necho 'ffmpeg version 0.0.1'\n",
            )
            bundle, platform = self.make_bundle(repo_root)
            session = PackageManagerSession(
                bundle,
                platform,
                no_sudo=True,
                check_only=False,
            )
            with mock.patch.dict(os.environ, env_with_path(fake_bin), clear=False):
                with mock.patch.object(session, "_ensure_packages"):
                    with self.assertRaises(EnvError):
                        session.ensure_tool("ffmpeg")


if __name__ == "__main__":
    unittest.main()
