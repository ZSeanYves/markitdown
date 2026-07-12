import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
QUALITY_LAB_DIR = "markitdown" + "-quality-lab"
QUALITY_LAB_ENV = "MARKITDOWN_" + "QUALITY_LAB"
FORBIDDEN_EXTERNAL_TEST_REFERENCES = (QUALITY_LAB_DIR, QUALITY_LAB_ENV)
IGNORED_PATH_PARTS = {".git", ".tmp", "_build", QUALITY_LAB_DIR}


class CoreTestIsolationTests(unittest.TestCase):
    def test_core_tests_do_not_reference_external_quality_lab(self) -> None:
        violations: list[str] = []
        for pattern in ("*_test.mbt", "*_wbtest.mbt", "test_*.py"):
            for path in ROOT.rglob(pattern):
                if IGNORED_PATH_PARTS.intersection(path.parts):
                    continue
                text = path.read_text(encoding="utf-8")
                for reference in FORBIDDEN_EXTERNAL_TEST_REFERENCES:
                    if reference in text:
                        violations.append(f"{path.relative_to(ROOT)}: {reference}")
        self.assertEqual(
            violations,
            [],
            "core MoonBit tests must be self-contained; external corpora belong "
            "in explicit regression jobs:\n" + "\n".join(violations),
        )


if __name__ == "__main__":
    unittest.main()
