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
        <class filename="formats/a.mbt"><lines><line number="1" hits="1"/></lines></class>
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
        runtime_file = next(
            item for item in summary["files"] if item["path"] == "formats/audio/runtime.mbt"
        )
        self.assertEqual(runtime_file["group"], "tools")
        self.assertFalse(summary["passed"])

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
