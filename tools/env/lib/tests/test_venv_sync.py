from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from helpers import write_text

from envkit.utils import EnvError
from envkit.venv_sync import (
    assert_version_satisfies,
    inspect_venv,
    locked_requirements_for_python,
)


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
        if argv == [str(self.python_path), "-m", "pip", "freeze", "--all"]:
            return subprocess.CompletedProcess(
                argv,
                0,
                "alpha==1.0.0\nbeta==2.0.0\npip==25.1.1\n"
                "setuptools==65.5.0\n",
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

    def test_inspect_venv_includes_locked_setuptools(self) -> None:
        write_text(
            self.lock_path,
            "alpha==1.0.0\nbeta==2.0.0\nsetuptools==83.0.0\n",
        )

        def fake_run_with_setuptools(
            argv: list[str], *_args, **_kwargs
        ) -> subprocess.CompletedProcess[str]:
            if argv == [str(self.python_path), "--version"]:
                return subprocess.CompletedProcess(
                    argv, 0, "Python 3.11.13\n", ""
                )
            if argv == [
                str(self.python_path),
                "-m",
                "pip",
                "freeze",
                "--all",
            ]:
                return subprocess.CompletedProcess(
                    argv,
                    0,
                    "alpha==1.0.0\nbeta==2.0.0\n"
                    "pip==25.1.1\nsetuptools==83.0.0\n",
                    "",
                )
            raise AssertionError(f"unexpected command: {argv}")

        with mock.patch(
            "envkit.venv_sync.run", side_effect=fake_run_with_setuptools
        ):
            state = inspect_venv(
                venv_path=self.venv_path,
                lock_path=self.lock_path,
                expected_python_version="3.11",
            )

        self.assertEqual(
            state.packages,
            ["alpha==1.0.0", "beta==2.0.0", "setuptools==83.0.0"],
        )

    def test_inspect_venv_rejects_package_drift(self) -> None:
        write_text(self.lock_path, "alpha==1.0.0\n")
        with mock.patch("envkit.venv_sync.run", side_effect=self.fake_run):
            with self.assertRaises(EnvError) as raised:
                inspect_venv(
                    venv_path=self.venv_path,
                    lock_path=self.lock_path,
                    expected_python_version="3.12",
                )
        self.assertIn("missing=[]", str(raised.exception))
        self.assertIn("unexpected=['beta==2.0.0']", str(raised.exception))

    def test_inspect_venv_rejects_python_version_drift(self) -> None:
        write_text(self.lock_path, "alpha==1.0.0\nbeta==2.0.0\n")
        with mock.patch("envkit.venv_sync.run", side_effect=self.fake_run):
            with self.assertRaises(EnvError):
                inspect_venv(
                    venv_path=self.venv_path,
                    lock_path=self.lock_path,
                    expected_python_version="3.11",
                )

    def test_python_requires_accepts_supported_minor(self) -> None:
        assert_version_satisfies("Python 3.13.5", ">=3.10,<3.14", "/python")

    def test_python_requires_rejects_newer_minor(self) -> None:
        with self.assertRaisesRegex(EnvError, "required >=3.10,<3.14"):
            assert_version_satisfies("Python 3.14.0", ">=3.10,<3.14", "/python")

    def test_lock_markers_follow_virtualenv_python_version(self) -> None:
        write_text(
            self.lock_path,
            'alpha==1.0.0\nbackport==2.0.0; python_version >= "3.13"\n',
        )
        self.assertEqual(
            locked_requirements_for_python(self.lock_path, "Python 3.12.9"),
            ["alpha==1.0.0"],
        )
        self.assertEqual(
            locked_requirements_for_python(self.lock_path, "Python 3.13.5"),
            ["alpha==1.0.0", "backport==2.0.0"],
        )


if __name__ == "__main__":
    unittest.main()
