import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

class ContractManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.checker = load("phase2_checker", ROOT / "tools/compatibility/check_contract_manifest.py")

    def test_repository_manifest_passes(self):
        self.assertEqual(self.checker.validate(), [])

    def test_unclassified_difference_is_rejected(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            (root / "tools/compatibility").mkdir(parents=True)
            manifest = json.loads((ROOT / "tools/compatibility/contract-manifest.json").read_text())
            manifest["cases"][0].pop("classification")
            (root / "tools/compatibility/contract-manifest.json").write_text(json.dumps(manifest))
            categories = (ROOT / "tools/compatibility/difference-categories.json").read_text()
            (root / "tools/compatibility/difference-categories.json").write_text(categories)
            self.assertTrue(any("classification" in e for e in self.checker.validate(root)))

    def test_reference_only_cases_cannot_claim_input_coverage(self):
        data = json.loads((ROOT / "tools/compatibility/contract-manifest.json").read_text())
        cases = [case for case in data["cases"] if case["source"] == "upstream-reference-only"]
        self.assertEqual(
            {case["format"] for case in cases},
            {"rss", "atom", "xls", "outlook-msg", "wikipedia", "youtube", "bing-serp", "eml"},
        )
        self.assertTrue(all(case["input_kinds"] == [] for case in cases))

if __name__ == "__main__":
    unittest.main()
