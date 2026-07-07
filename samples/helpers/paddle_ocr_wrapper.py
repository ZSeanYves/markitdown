#!/usr/bin/env python3
"""Official MARKITDOWN_PADDLE_OCR_CMD wrapper.

Stable wrapper contract:

  paddle_ocr_wrapper.py <image_path> [--lang <LANG>]

It prints the JSON payload consumed by `formats/ocr/runtime.mbt`.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


LANGUAGE_ALIASES = {
    "eng": "en",
    "en": "en",
    "chi_sim": "ch",
    "chi_tra": "chinese_cht",
    "jpn": "japan",
    "kor": "korean",
}


def fail(message: str, code: int = 2) -> int:
    print(message, file=sys.stderr)
    return code


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Official MARKITDOWN_PADDLE_OCR_CMD wrapper"
    )
    parser.add_argument("image_path")
    parser.add_argument("--lang", dest="language")
    return parser.parse_args()


def mapped_language(language: str | None) -> str | None:
    if language is None:
        return None
    trimmed = language.strip()
    if not trimmed:
        return None
    return LANGUAGE_ALIASES.get(trimmed, trimmed)


def read_image_size(image_path: str) -> tuple[float | None, float | None]:
    try:
        from PIL import Image

        with Image.open(image_path) as image:
            width, height = image.size
        return float(width), float(height)
    except Exception:
        return None, None


def load_paddle():
    try:
        import paddleocr
        from paddleocr import PaddleOCR
    except Exception as exc:
        raise RuntimeError(
            "failed to import `paddleocr`; install PaddleOCR in the Python "
            "runtime used by MARKITDOWN_PADDLE_OCR_CMD"
        ) from exc
    return paddleocr, PaddleOCR


def build_engine(paddle_ocr_cls, language: str | None):
    kwargs = {}
    if language:
        kwargs["lang"] = language
    try:
        return paddle_ocr_cls(use_angle_cls=True, **kwargs)
    except TypeError:
        return paddle_ocr_cls(**kwargs)


def normalize_lines(raw_result):
    if raw_result is None:
        return []
    if isinstance(raw_result, list) and raw_result and isinstance(raw_result[0], list):
        first = raw_result[0]
        if first and isinstance(first[0], list) and len(first[0]) == 2:
            return raw_result
        return [first]
    if isinstance(raw_result, list):
        return [raw_result]
    return []


def line_bbox(points):
    try:
        xs = [float(point[0]) for point in points]
        ys = [float(point[1]) for point in points]
    except Exception:
        return None
    if not xs or not ys:
        return None
    return {
        "x0": min(xs),
        "y0": min(ys),
        "x1": max(xs),
        "y1": max(ys),
    }


def line_confidence(value) -> float | None:
    try:
        return float(value)
    except Exception:
        return None


def word_models(text: str, confidence: float | None):
    parts = [part for part in text.split() if part]
    if not parts:
        parts = [text] if text else []
    return [
        {
            "word_index": index,
            "text": part,
            **({"confidence": confidence} if confidence is not None else {}),
        }
        for index, part in enumerate(parts)
    ]


def page_from_lines(page_index: int, image_path: str, language: str | None, lines):
    width, height = read_image_size(image_path)
    blocks = []
    for block_index, entry in enumerate(lines):
        if not isinstance(entry, list) or len(entry) != 2:
            continue
        points, payload = entry
        if not isinstance(payload, (list, tuple)) or len(payload) != 2:
            continue
        text = str(payload[0]).strip()
        if not text:
            continue
        confidence = line_confidence(payload[1])
        bbox = line_bbox(points)
        line = {
            "line_index": 0,
            "text": text,
            "words": word_models(text, confidence),
        }
        if bbox is not None:
            line["bbox"] = bbox
        if confidence is not None:
            line["confidence"] = confidence
        block = {
            "block_index": block_index,
            "lines": [line],
        }
        if bbox is not None:
            block["bbox"] = bbox
        if confidence is not None:
            block["confidence"] = confidence
        blocks.append(block)

    if not blocks:
        return None

    page = {
        "page_index": page_index,
        "blocks": blocks,
    }
    if width is not None:
        page["width"] = width
    if height is not None:
        page["height"] = height
    if language:
        page["language"] = language
    return page


def main() -> int:
    args = parse_args()
    image_path = str(Path(args.image_path))
    requested_language = args.language.strip() if args.language else None
    wrapper_language = mapped_language(requested_language)

    if not Path(image_path).exists():
        return fail(f"input image does not exist: {image_path}")

    try:
        paddleocr_module, paddle_ocr_cls = load_paddle()
        engine = build_engine(paddle_ocr_cls, wrapper_language)
        raw_result = engine.ocr(image_path, cls=True)
    except Exception as exc:
        return fail(f"PaddleOCR wrapper execution failed: {exc}")

    normalized_pages = normalize_lines(raw_result)
    pages = []
    for page_index, page_lines in enumerate(normalized_pages):
        page = page_from_lines(page_index, image_path, requested_language, page_lines)
        if page is not None:
            pages.append(page)

    payload = {
        "provider_name": "paddle_ocr",
        "provider_version": getattr(paddleocr_module, "__version__", None),
        "diagnostics": [
            "wrapper=samples/helpers/paddle_ocr_wrapper.py",
            f"requested_lang={requested_language or 'none'}",
            f"wrapper_lang={wrapper_language or 'none'}",
        ],
        "pages": pages,
    }
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
