import importlib.util
import unittest
import zipfile
from io import BytesIO
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
MODULE_PATH = ROOT / "tools/regression/mutation_smoke.py"
SPEC = importlib.util.spec_from_file_location("mutation_smoke", MODULE_PATH)
mutation_smoke = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(mutation_smoke)


class MutationSmokeTests(unittest.TestCase):
    def test_mutation_categories_are_complete_and_deterministic(self) -> None:
        first = mutation_smoke.mutations("html", b"<p>text</p>")
        second = mutation_smoke.mutations("html", b"<p>text</p>")
        self.assertEqual(first, second)
        self.assertEqual(
            [name for name, _data in first],
            [
                "truncate_half",
                "flip_middle",
                "trailing_garbage",
                "depth_inflation",
                "size_deception",
                "compression_bomb",
            ],
        )

    def test_compression_bomb_is_small_but_declares_over_128_mib(self) -> None:
        payload = mutation_smoke.compression_bomb_zip()
        self.assertLess(len(payload), 1024 * 1024)
        with zipfile.ZipFile(BytesIO(payload)) as archive:
            self.assertGreater(archive.getinfo("bomb.bin").file_size, 128 * 1024 * 1024)

    def test_size_deception_patches_zip_central_directory(self) -> None:
        payload = mutation_smoke.compression_bomb_zip()
        mutated = mutation_smoke.deceive_size("zip", payload)
        central = mutated.find(b"PK\x01\x02")
        self.assertGreaterEqual(central, 0)
        self.assertEqual(
            int.from_bytes(mutated[central + 24 : central + 28], "little"),
            0x7FFFFFFF,
        )


if __name__ == "__main__":
    unittest.main()
