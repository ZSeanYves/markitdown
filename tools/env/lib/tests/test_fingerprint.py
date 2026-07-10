from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from helpers import write_minimal_config

from envkit.config import ConfigBundle
from envkit.fingerprint import render_env_file, render_fingerprint, runtime_args_snapshot


class FingerprintTests(unittest.TestCase):
    def test_render_env_file_is_stable(self) -> None:
        rendered = render_env_file(
            {"MARKITDOWN_RUNTIME_PYTHON": "/tmp/venv/bin/python"},
            {"TZ": "UTC", "LANG": "en_US.UTF-8"},
        )
        self.assertIn("export TZ=UTC\n", rendered)
        self.assertIn("export LANG=en_US.UTF-8\n", rendered)
        self.assertIn(
            "export MARKITDOWN_RUNTIME_PYTHON=/tmp/venv/bin/python\n",
            rendered,
        )

    def test_runtime_snapshot_balance_includes_pdf_and_ocr_args(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo_root = Path(tmp) / "repo"
            write_minimal_config(repo_root)
            bundle = ConfigBundle(repo_root)
            snapshot = runtime_args_snapshot(bundle, "balance")
        self.assertEqual(snapshot["commands"]["pdftoppm"], ["-r", "150", "-png"])
        self.assertEqual(snapshot["commands"]["tesseract"], ["--oem", "1", "--psm", "6"])

    def test_render_fingerprint_is_deterministic(self) -> None:
        payload = {
            "z_key": 1,
            "a_key": {"nested_b": 2, "nested_a": 1},
        }
        rendered = render_fingerprint(payload)
        reparsed = json.loads(rendered)
        self.assertEqual(reparsed["a_key"]["nested_a"], 1)
        self.assertLess(rendered.find('"a_key"'), rendered.find('"z_key"'))


if __name__ == "__main__":
    unittest.main()
