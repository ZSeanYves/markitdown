from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

from helpers import ROOT

from envkit.config import ConfigBundle
from envkit.doctor import assert_runtime_contracts
from envkit.runtime_contract import (
    ffmpeg_normalize_args,
    paddle_env,
    paddle_init_kwargs,
    paddle_predict_kwargs,
    stable_env,
)


def import_module_from_path(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to import module from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ContractTests(unittest.TestCase):
    def test_repo_runtime_contracts_match_config(self) -> None:
        bundle = ConfigBundle(ROOT)
        assert_runtime_contracts(ROOT, bundle.runtime_args)

    def test_audio_wrapper_uses_shared_runtime_contract(self) -> None:
        module = import_module_from_path(
            "audio_transcribe_wrapper",
            ROOT / "tools" / "env" / "wrappers" / "audio_transcribe_wrapper.py",
        )
        self.assertEqual(module.REQUIRED_RUNTIME_ENV, stable_env(str(ROOT)))
        self.assertEqual(module.FFMPEG_NORMALIZE_ARGS, ffmpeg_normalize_args(str(ROOT)))

    def test_paddle_wrapper_uses_shared_runtime_contract(self) -> None:
        module = import_module_from_path(
            "paddle_ocr_wrapper",
            ROOT / "tools" / "env" / "wrappers" / "paddle_ocr_wrapper.py",
        )
        self.assertEqual(module.REQUIRED_RUNTIME_ENV, stable_env(str(ROOT)))
        self.assertEqual(module.PADDLE_ENV, paddle_env(str(ROOT)))
        self.assertEqual(module.PADDLE_INIT_KWARGS, paddle_init_kwargs(str(ROOT)))
        self.assertEqual(module.PADDLE_PREDICT_KWARGS, paddle_predict_kwargs(str(ROOT)))


if __name__ == "__main__":
    unittest.main()
