from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from helpers import ROOT  # noqa: F401 - importing helpers configures envkit path

from envkit.manager import environment_lock
from envkit.utils import write_text_if_changed


class AtomicStateTests(unittest.TestCase):
    def test_atomic_text_write_replaces_complete_content(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state" / "fingerprint.json"
            write_text_if_changed(path, "first\n")
            write_text_if_changed(path, "second\n")
            self.assertEqual(path.read_text(encoding="utf-8"), "second\n")
            self.assertEqual(list(path.parent.glob(f".{path.name}.*")), [])

    def test_environment_lock_is_created_and_reusable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            env_root = Path(tmp) / "env"
            with environment_lock(env_root):
                self.assertTrue((env_root / ".install.lock").is_file())
            with environment_lock(env_root):
                self.assertTrue((env_root / ".install.lock").is_file())


if __name__ == "__main__":
    unittest.main()
