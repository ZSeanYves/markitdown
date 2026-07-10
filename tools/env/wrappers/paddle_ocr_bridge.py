#!/usr/bin/env python3
"""Compatibility shim for the official Paddle OCR wrapper."""

from pathlib import Path
import runpy


if __name__ == "__main__":
    wrapper = Path(__file__).resolve().parents[0] / "paddle_ocr_wrapper.py"
    runpy.run_path(str(wrapper), run_name="__main__")
