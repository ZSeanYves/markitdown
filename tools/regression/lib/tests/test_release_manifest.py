import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SCRIPT = ROOT / "tools/regression/lib/shared/release_manifest.py"


class ReleaseManifestTests(unittest.TestCase):
    def test_writes_environment_and_existing_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp = Path(raw_tmp)
            artifact = tmp / "summary.md"
            artifact.write_text("pass\n", encoding="utf-8")
            output = tmp / "manifest.json"
            completed = subprocess.run(
                [
                    sys.executable, str(SCRIPT), "--root", str(ROOT),
                    "--output", str(output), "--command", "moon test",
                    "--status", "pass", "--exit-code", "0", "--started-at", "2026-01-01T00:00:00Z",
                    "--finished-at", "2026-01-01T00:01:00Z", "--artifact", str(artifact),
                ],
                check=False,
            )
            self.assertEqual(completed.returncode, 0)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(payload["schema_version"], 2)
            self.assertEqual(payload["status"], "pass")
            self.assertEqual(payload["result_summary"]["exit_code"], 0)
            self.assertEqual(payload["result_summary"]["artifact_count"], 1)
            self.assertEqual(payload["missing_artifacts"], [])
            self.assertTrue(payload["repository_sha"])
            cli_fingerprint = payload["runtime_fingerprints"]["cli"]
            self.assertIsInstance(cli_fingerprint["available"], bool)
            if cli_fingerprint["available"]:
                self.assertEqual(len(cli_fingerprint["sha256"]), 64)
            else:
                self.assertIsNone(cli_fingerprint["sha256"])
            self.assertIn("available", payload["runtime_fingerprints"]["pdftoppm"])

    def test_missing_commands_are_recorded_as_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            tmp = Path(raw_tmp)
            output = tmp / "manifest.json"
            completed = subprocess.run(
                [
                    sys.executable, str(SCRIPT), "--root", str(ROOT),
                    "--output", str(output), "--command", "moon test",
                    "--status", "pass", "--exit-code", "0", "--started-at", "start",
                    "--finished-at", "finish",
                ],
                check=False,
                env={"PATH": ""},
            )
            self.assertEqual(completed.returncode, 0)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(payload["moon_version"], "unavailable")
            self.assertFalse(payload["runtime_fingerprints"]["pdftoppm"]["available"])

    def test_missing_artifact_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as raw_tmp:
            output = Path(raw_tmp) / "manifest.json"
            completed = subprocess.run(
                [
                    sys.executable, str(SCRIPT), "--root", str(ROOT),
                    "--output", str(output), "--command", "moon test",
                    "--status", "pass", "--exit-code", "0", "--started-at", "start",
                    "--finished-at", "finish", "--artifact", "missing.file",
                ],
                check=False,
            )
            self.assertEqual(completed.returncode, 1)
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(payload["missing_artifacts"], ["missing.file"])


if __name__ == "__main__":
    unittest.main()
