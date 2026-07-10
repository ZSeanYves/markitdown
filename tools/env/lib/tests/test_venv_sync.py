from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from helpers import write_text

from envkit.utils import EnvError
from envkit.venv_sync import inspect_venv


class VenvSyncTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.venv_path = self.root / ".venv"
        self.python_path = self.venv_path / "bin" / "python"
        self.python_path.parent.mkdir(parents=True, exist_ok=True)
        self.python_path.write_text("", encoding="utf-8")
        self.lock_path = self.root / "requirements.lock"

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def fake_run(self, argv: list[str], *args, **kwargs) -> subprocess.CompletedProcess[str]:
        if argv == [str(self.python_path), "--version"]:
            return subprocess.CompletedProcess(argv, 0, "Python 3.12.4\n", "")
        if argv == [str(self.python_path), "-m", "pip", "freeze"]:
            return subprocess.CompletedProcess(
                argv,
                0,
                "alpha==1.0.0\nbeta==2.0.0\n",
                "",
            )
        raise AssertionError(f"unexpected command: {argv}")

    def test_inspect_venv_accepts_exact_lock_match(self) -> None:
        write_text(self.lock_path, "alpha==1.0.0\nbeta==2.0.0\n")
        with mock.patch("envkit.venv_sync.run", side_effect=self.fake_run):
            state = inspect_venv(
                venv_path=self.venv_path,
                lock_path=self.lock_path,
                expected_python_version="3.12",
            )
        self.assertEqual(state.python_version, "Python 3.12.4")
        self.assertEqual(state.packages, ["alpha==1.0.0", "beta==2.0.0"])

    def test_inspect_venv_rejects_package_drift(self) -> None:
        write_text(self.lock_path, "alpha==1.0.0\n")
        with mock.patch("envkit.venv_sync.run", side_effect=self.fake_run):
            with self.assertRaises(EnvError):
                inspect_venv(
                    venv_path=self.venv_path,
                    lock_path=self.lock_path,
                    expected_python_version="3.12",
                )

    def test_inspect_venv_rejects_python_version_drift(self) -> None:
        write_text(self.lock_path, "alpha==1.0.0\nbeta==2.0.0\n")
        with mock.patch("envkit.venv_sync.run", side_effect=self.fake_run):
            with self.assertRaises(EnvError):
                inspect_venv(
                    venv_path=self.venv_path,
                    lock_path=self.lock_path,
                    expected_python_version="3.11",
                )


if __name__ == "__main__":
    unittest.main()
