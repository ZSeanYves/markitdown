from __future__ import annotations

import hashlib
import importlib.util
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
MODULE_PATH = ROOT / "tools/regression/lib/quality/evaluate_signals.py"
SPEC = importlib.util.spec_from_file_location("quality_signal_evaluator", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def test_asset_evidence_signals_validate_real_files(tmp_path: Path) -> None:
    asset = tmp_path / "assets/image01.png"
    asset.parent.mkdir(parents=True)
    payload = b"\x89PNG\r\n\x1a\ncontract"
    asset.write_bytes(payload)
    snapshot = MODULE.Snapshot("", "", "", "", [], 1, tmp_path)
    evaluator = MODULE.Evaluator(snapshot)
    digest = hashlib.sha256(payload).hexdigest()
    assert evaluator.evaluate("asset_count_exact:1")
    assert evaluator.evaluate("asset_exists:assets/image01.png")
    assert evaluator.evaluate("asset_magic:assets/image01.png=png")
    assert evaluator.evaluate(f"asset_sha256:assets/image01.png={digest}")
    assert not evaluator.evaluate("asset_magic:assets/image01.png=jpeg")


def test_asset_evidence_signals_reject_traversal(tmp_path: Path) -> None:
    snapshot = MODULE.Snapshot("", "", "", "", [], 0, tmp_path)
    evaluator = MODULE.Evaluator(snapshot)
    try:
        evaluator.evaluate("asset_exists:../outside.png")
    except SystemExit as exc:
        assert "unsafe asset signal path" in str(exc)
    else:
        raise AssertionError("expected traversal signal to fail closed")
