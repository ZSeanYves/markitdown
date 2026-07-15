import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
MODULE_PATH = ROOT / "tools/regression/lib/coverage_gate.py"
SPEC = importlib.util.spec_from_file_location("coverage_gate", MODULE_PATH)
coverage_gate = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(coverage_gate)


class CoverageGateTests(unittest.TestCase):
    def test_groups_lines_and_excludes_static_data(self) -> None:
        xml = """<coverage><packages><package><classes>
        <class filename="convert/a.mbt"><lines><line number="1" hits="1"/><line number="2" hits="0"/></lines></class>
        <class filename="formats/html/parser.mbt"><lines><line number="1" hits="1"/></lines></class>
        <class filename="formats/audio/runtime.mbt"><lines><line number="1" hits="1"/><line number="2" hits="0"/></lines></class>
        <class filename="cli/a.mbt"><lines><line number="1" hits="0"/></lines></class>
        <class filename="format_readers/pdf/gb2312_data.mbt"><lines><line number="1" hits="0"/></lines></class>
        </classes></package></packages></coverage>"""
        with tempfile.TemporaryDirectory() as raw_tmp:
            path = Path(raw_tmp) / "coverage.xml"
            path.write_text(xml, encoding="utf-8")
            summary = coverage_gate.summarize(path)
        groups = {item["name"]: item for item in summary["groups"]}
        self.assertEqual(groups["core"]["rate"], 50.0)
        self.assertEqual(groups["formats"]["rate"], 100.0)
        self.assertEqual(groups["tools"]["rate"], 33.3333)
        self.assertEqual(groups["core"]["threshold"], 90.0)
        self.assertEqual(groups["formats"]["threshold"], 80.0)
        self.assertEqual(groups["tools"]["threshold"], 70.0)
        runtime_file = next(
            item for item in summary["files"] if item["path"] == "formats/audio/runtime.mbt"
        )
        self.assertEqual(runtime_file["group"], "tools")
        self.assertFalse(summary["passed"])
        formats = {item["name"]: item for item in summary["formats"]}
        self.assertEqual(formats["html"]["rate"], 100.0)
        self.assertEqual(formats["audio"]["rate"], 50.0)

    def test_format_mapping_and_ratchet_enforce_half_point_drop(self) -> None:
        files = [
            {"path": "format_readers/ooxml/docx/a.mbt", "covered": 79, "valid": 100},
            {"path": "format_readers/odf/odt/a.mbt", "covered": 90, "valid": 100},
            {"path": "formats/shared/a.mbt", "covered": 0, "valid": 100},
        ]
        formats = coverage_gate.aggregate_formats(files)
        self.assertEqual([item["name"] for item in formats], ["docx", "odt"])
        with tempfile.TemporaryDirectory() as raw_tmp:
            baseline = Path(raw_tmp) / "baseline.json"
            baseline.write_text(
                '{"formats":[{"name":"docx","rate":79.6},{"name":"odt","rate":90.4}]}',
                encoding="utf-8",
            )
            ratchet = coverage_gate.format_ratchet(
                {"formats": formats}, baseline, 0.5
            )
        self.assertFalse(ratchet["passed"])
        entries = {item["name"]: item for item in ratchet["entries"]}
        self.assertFalse(entries["docx"]["passed"])
        self.assertTrue(entries["odt"]["passed"])

    def test_writes_all_report_formats(self) -> None:
        summary = {"groups": [], "files": [], "excluded_files": [], "passed": True}
        with tempfile.TemporaryDirectory() as raw_tmp:
            output = Path(raw_tmp)
            coverage_gate.write_outputs(summary, output)
            self.assertTrue((output / "coverage.json").exists())
            self.assertTrue((output / "coverage.tsv").exists())
            self.assertTrue((output / "coverage.md").exists())


if __name__ == "__main__":
    unittest.main()
