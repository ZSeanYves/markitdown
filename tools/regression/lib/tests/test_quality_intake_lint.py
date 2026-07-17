import json
import tempfile
import unittest
from pathlib import Path

from tools.regression.lib.quality.intake_lint import lint


class IntakeLintTest(unittest.TestCase):
    def write_fixture(self, with_audit=True):
        root = Path(tempfile.mkdtemp())
        source = root / "external_quality" / "txt" / "fixture"
        (source / "_audit").mkdir(parents=True)
        payload = source / "sample.txt"
        payload.write_text("boundary sample\n", encoding="utf-8")
        (source / "LICENSE-fixture.txt").write_text("MIT\n", encoding="utf-8")
        import hashlib
        digest = hashlib.sha256(payload.read_bytes()).hexdigest()
        license_digest = hashlib.sha256((source / "LICENSE-fixture.txt").read_bytes()).hexdigest()
        if with_audit:
            (source / "_audit" / "AUDIT.json").write_text(json.dumps({
                "source_id": "fixture_source", "retrieval_url": "https://example.test/a",
                "final_url": "https://example.test/a", "retrieved_at": "2026-07-16T00:00:00Z",
                "source_revision": "v1", "license_spdx": "MIT", "license_url": "https://example.test/license",
                "license_text_sha256": license_digest, "payload_sha256": digest,
                "payload_bytes": payload.stat().st_size, "redistribution_basis": "fixture license",
                "privacy_status": "public/no personal data", "review_status": "approved",
                "reviewer": "local", "reviewed_at": "2026-07-16T00:00:00Z",
            }), encoding="utf-8")
        manifest = root / "MANIFEST.tsv"
        manifest.write_text(
            "id\tformat\tpath\tsource_id\tlicense_status\tlicense_review_status\tprivacy\texpected_signals\toriginal_url\tlocal_cache_path\n"
            f"fixture\ttxt\texternal_quality/txt/fixture/sample.txt\tfixture_source\tMIT\tapproved\tpublic/no personal data\tno_empty_output\thttps://example.test/a\texternal_quality/txt/fixture\n",
            encoding="utf-8",
        )
        catalog = root / "SOURCE_CATALOG.tsv"
        catalog.write_text("source_id\tsource_name\nfixture_source\tFixture\n", encoding="utf-8")
        return root, manifest, catalog

    def test_complete_audit_passes(self):
        root, manifest, catalog = self.write_fixture()
        errors, warnings = lint(root, manifest, catalog)
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])

    def test_missing_audit_uses_legacy_warning(self):
        root, manifest, catalog = self.write_fixture(with_audit=False)
        errors, warnings = lint(root, manifest, catalog)
        self.assertEqual(errors, [])
        self.assertEqual(len(warnings), 1)


if __name__ == "__main__":
    unittest.main()
