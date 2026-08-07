import importlib.util
import json
import os
import tempfile
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
        cls.documentation = load_module(
            "check_documentation", ROOT / "tools/governance/check_documentation.py"
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

    def test_maintenance_inventory_matches_sources(self):
        self.assertEqual(self.baseline.validate_maintenance_inventory(), [])
        data = json.loads(
            (ROOT / "tools/governance/phase0-maintenance-inventory.json").read_text()
        )
        self.assertFalse(data["network"]["enabled"])
        self.assertEqual(len(data["external_commands"]), 5)
        self.assertEqual(data["licenses"]["project"]["spdx"], "Apache-2.0")

    def test_pr_policy_requires_explanation_for_generated_files(self):
        body = "\n".join(self.policy.REQUIRED_HEADINGS)
        self.assertEqual(self.policy.validate(body, []), [])
        errors = self.policy.validate(body, ["src/core/pkg.generated.mbti"])
        self.assertTrue(any("generated/golden" in error for error in errors))
        explained = body + "\n- Generated artifacts and regeneration command: moon info\n"
        self.assertEqual(self.policy.validate(explained, ["src/core/pkg.generated.mbti"]), [])
        api_body = (
            explained
            + "\n- Risk: `R3`\n- RFC/ADR: docs/rfcs/0001-api-change.md\n"
        )
        self.assertEqual(
            self.policy.validate(api_body, ["src/api/pkg.generated.mbti"]), []
        )

    def test_phase1_architecture_contract_passes_repository(self):
        self.assertEqual(self.architecture.verify(), [])
        self.assertLessEqual(self.architecture.moon_package_count(ROOT), 68)
        self.assertLessEqual(
            self.architecture.public_all_mutable_record_count(ROOT), 22
        )
        self.assertEqual(self.architecture.moon_packages_outside_source(ROOT), [])

    def test_phase1_rejects_internal_type_leaks_and_deep_imports(self):
        errors = self.architecture.api_surface_errors(
            'import { "ZSeanYves/markitdown/internal/parser" }\n',
            'import { "ZSeanYves/markitdown/internal/parser" }\n',
        )
        self.assertTrue(any("leaks internal" in error for error in errors))
        errors = self.architecture.api_import_errors(
            {"ZSeanYves/markitdown/formats/pdf"}
        )
        self.assertTrue(any("unapproved" in error for error in errors))

    def test_source_root_rejects_moon_packages_outside_src(self):
        with tempfile.TemporaryDirectory() as raw_tmp:
            root = Path(raw_tmp)
            (root / "src/api").mkdir(parents=True)
            (root / "src/api/moon.pkg").write_text("", encoding="utf-8")
            (root / "stray").mkdir()
            (root / "stray/moon.pkg").write_text("", encoding="utf-8")
            self.assertEqual(
                self.architecture.moon_packages_outside_source(root),
                ["stray/moon.pkg"],
            )

    def test_documentation_contract_passes_repository(self):
        self.assertEqual(self.documentation.verify(), [])

    def test_documentation_link_parser_only_returns_local_paths(self):
        self.assertEqual(
            self.documentation.local_link_target("../docs/README.md#lifecycle"),
            "../docs/README.md",
        )
        self.assertEqual(
            self.documentation.local_link_target("<../path with spaces/README.md>"),
            "../path with spaces/README.md",
        )
        self.assertIsNone(
            self.documentation.local_link_target("https://example.com/reference")
        )
        self.assertIsNone(self.documentation.local_link_target("#local-heading"))

    def test_documentation_performance_table_parser(self):
        table = "| PDF | 2 | 5.62x | 5.62x |\n| DOCX | 1 | 64.11x | 285.79x |\n"
        self.assertEqual(
            self.documentation.performance_format_rows(table),
            {
                "pdf": (2, "5.62", "5.62"),
                "docx": (1, "64.11", "285.79"),
            },
        )


if __name__ == "__main__":
    unittest.main()
