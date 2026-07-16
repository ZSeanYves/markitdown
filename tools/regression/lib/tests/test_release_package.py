from __future__ import annotations

import hashlib
import json
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / "tools" / "release" / "package.py"


class ReleasePackageTest(unittest.TestCase):
    def test_package_is_reproducible_and_emits_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / "markitdown-mb"
            binary.write_text("#!/bin/sh\nprintf '%s\\n' 'markitdown-mb 0.7.0'\n")
            binary.chmod(binary.stat().st_mode | stat.S_IXUSR)
            output = root / "dist"
            command = [
                sys.executable,
                str(PACKAGE),
                "--binary",
                str(binary),
                "--platform",
                "test-platform",
                "--output",
                str(output),
            ]
            subprocess.run(command, check=True, capture_output=True, text=True)
            archive = output / "markitdown-mb-0.7.0-test-platform.tar.gz"
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            subprocess.run(command, check=True, capture_output=True, text=True)
            self.assertEqual(digest, hashlib.sha256(archive.read_bytes()).hexdigest())
            self.assertEqual(
                f"{digest}  {archive.name}\n",
                (output / f"{archive.name}.sha256").read_text(),
            )
            sbom = json.loads((output / "markitdown-mb-0.7.0-test-platform.spdx.json").read_text())
            self.assertEqual(sbom["spdxVersion"], "SPDX-2.3")
            self.assertEqual(sbom["packages"][0]["versionInfo"], "0.7.0")

    def test_package_rejects_version_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / "markitdown-mb"
            binary.write_text("#!/bin/sh\nprintf '%s\\n' 'markitdown-mb 0.6.0'\n")
            binary.chmod(binary.stat().st_mode | stat.S_IXUSR)
            result = subprocess.run(
                [sys.executable, str(PACKAGE), "--binary", str(binary), "--platform", "test"],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("version mismatch", result.stderr)


if __name__ == "__main__":
    unittest.main()
