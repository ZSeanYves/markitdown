import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SPEC = importlib.util.spec_from_file_location(
    "self_baseline", ROOT / "tools" / "regression" / "self_baseline.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class SelfBaselineTest(unittest.TestCase):
    def test_aggregate_requires_stable_five_samples(self):
        rows = [
            {
                "status": "ok",
                "bench_id": "case",
                "tool": "moonbit-cli",
                "wall_us": value,
                "peak_rss_kb": 100,
                "output_sha256": "a" * 64,
                "input_sha256": "b" * 64,
            }
            for value in (10, 11, 12, 13, 14)
        ]
        case = MODULE.aggregate_cases(rows)[0]
        self.assertEqual(case["median_wall_us"], 12)
        self.assertEqual(case["peak_rss_kb"], 100)

        engine_rows = [dict(row, tool="moonbit-engine", peak_rss_kb=None) for row in rows]
        self.assertIsNone(MODULE.aggregate_cases(engine_rows)[0]["peak_rss_kb"])

    def test_enforce_rejects_more_than_ten_percent(self):
        base = {
            "review_status": "approved",
            "platform_key": "macos-arm64",
            "runner_class": "local",
            "fingerprints": {"moonbit": "x"},
            "cases": [{
                "bench_id": "case", "tool": "moonbit-cli",
                "input_sha256": "a", "output_sha256": "b",
                "median_wall_us": 100, "peak_rss_kb": 100,
            }],
        }
        candidate = json.loads(json.dumps(base))
        candidate["review_status"] = "candidate"
        candidate["cases"][0]["median_wall_us"] = 111
        with tempfile.TemporaryDirectory() as directory:
            baseline_path = Path(directory) / "base.json"
            candidate_path = Path(directory) / "candidate.json"
            baseline_path.write_text(json.dumps(base))
            candidate_path.write_text(json.dumps(candidate))
            args = type("Args", (), {"baseline": baseline_path, "candidate": candidate_path})
            self.assertEqual(MODULE.enforce(args), 1)


if __name__ == "__main__":
    unittest.main()
