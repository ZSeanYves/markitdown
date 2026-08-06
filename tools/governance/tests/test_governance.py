import importlib.util
import json
import os
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GovernanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = load_module("collect_baseline", ROOT / "tools/governance/collect_baseline.py")
        cls.toolchain = load_module("check_toolchain", ROOT / "tools/governance/check_toolchain.py")
        cls.policy = load_module("check_pr_policy", ROOT / "tools/governance/check_pr_policy.py")
        cls.architecture = load_module(
            "check_architecture", ROOT / "tools/governance/check_architecture.py"
        )

    def test_toolchain_parser_reads_all_components(self):
        output = """moon 0.1.20260803 (c19f78e 2026-08-03) ~/.moon/bin/moon
moonc v0.10.6+80dc50f24 (2026-08-04) ~/.moon/bin/moonc
moonrun 0.1.20260803 (c19f78e 2026-08-03) ~/.moon/bin/moonrun
"""
        self.assertEqual(
            self.toolchain.moon_versions(output),
            {
                "moon_version": "0.1.20260803",
                "moonc_version": "v0.10.6+80dc50f24",
                "moonrun_version": "0.1.20260803",
            },
        )

    def test_fixture_manifest_is_sorted_and_hashable(self):
        files = [
            "samples/fixtures/rejections/epub/epub_missing_container.epub",
            "samples/fixtures/contracts/txt/txt_plain.txt",
        ]
        lines, digest = self.baseline.fixture_digest(files)
        self.assertEqual(lines, [f"{self.baseline.sha256_file(ROOT / path)}  {path}" for path in sorted(files)])
        self.assertEqual(len(digest), 64)

    def test_baseline_contains_required_contract(self):
        data = json.loads((ROOT / "tools/governance/phase0-baseline.json").read_text())
        self.assertEqual(data["upstream"]["tag"], "v0.1.7")
        self.assertEqual(data["upstream"]["commit"], "fd239d5d2be43d9b68329730206b9312c7d5a388")
        self.assertEqual(data["native_baseline"]["targets"]["native"], {"tests": 894, "passed": 894})
        self.assertGreaterEqual(data["inventory"]["moon_packages"], 100)

    def test_pr_policy_requires_explanation_for_generated_files(self):
        body = "\n".join(self.policy.REQUIRED_HEADINGS)
        self.assertEqual(self.policy.validate(body, []), [])
        errors = self.policy.validate(body, ["core/pkg.generated.mbti"])
        self.assertTrue(any("generated/golden" in error for error in errors))
        explained = body + "\n- Generated artifacts and regeneration command: moon info\n"
        self.assertEqual(self.policy.validate(explained, ["core/pkg.generated.mbti"]), [])
        api_body = (
            explained
            + "\n- Risk: `R3`\n- RFC/ADR: docs/rfcs/0001-api-change.md\n"
        )
        self.assertEqual(
            self.policy.validate(api_body, ["api/pkg.generated.mbti"]), []
        )

    def test_phase1_architecture_contract_passes_repository(self):
        self.assertEqual(self.architecture.verify(), [])

    def test_phase1_rejects_internal_type_leaks_and_deep_imports(self):
        errors = self.architecture.api_surface_errors(
            'import { "ZSeanYves/markitdown/parser" }\n',
            'import { "ZSeanYves/markitdown/parser" }\n',
        )
        self.assertTrue(any("leaks internal" in error for error in errors))
        errors = self.architecture.api_import_errors(
            {"ZSeanYves/markitdown/formats/pdf"}
        )
        self.assertTrue(any("unapproved" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
