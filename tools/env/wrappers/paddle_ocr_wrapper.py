#!/usr/bin/env python3
"""Official MARKITDOWN_PADDLE_OCR_CMD wrapper.

Stable wrapper contract:

  paddle_ocr_wrapper.py --batch-json <request_json_path> --result-json <result_json_path>

The request JSON must contain:

  {
    "provider": "paddle_ocr",
    "version": "v2",
    "jobs": [
      {
        "job_id": "...",
        "image_path": "...",
        "language": "eng"
      }
    ]
  }
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

MODULE_ROOT = Path(
    os.environ.get("MARKITDOWN_MODULE_ROOT", Path(__file__).resolve().parents[3])
)
LIB_ROOT = MODULE_ROOT / "tools" / "env" / "lib"
if str(LIB_ROOT) not in sys.path:
    sys.path.insert(0, str(LIB_ROOT))

from envkit.runtime_contract import (  # noqa: E402
    MODEL_METADATA_NAME,
    paddle_env,
    paddle_init_kwargs,
    paddle_predict_kwargs,
    stable_env,
)

LANGUAGE_ALIASES = {
    "eng": "en",
    "en": "en",
    "chi_sim": "ch",
    "chi_tra": "chinese_cht",
    "jpn": "japan",
    "kor": "korean",
}

REQUIRED_RUNTIME_ENV = stable_env(str(MODULE_ROOT))
PADDLE_ENV = paddle_env(str(MODULE_ROOT))
PADDLE_INIT_KWARGS = paddle_init_kwargs(str(MODULE_ROOT))
PADDLE_PREDICT_KWARGS = paddle_predict_kwargs(str(MODULE_ROOT))
MODEL_REQUIRED_FILES = ("inference.pdiparams", "inference.json", "inference.yml")
DEFAULT_MODEL_ENV = (
    "MARKITDOWN_PADDLE_OCR_DEFAULT_DET_MODEL_DIR",
    "MARKITDOWN_PADDLE_OCR_DEFAULT_REC_MODEL_DIR",
    "ocr-default-det",
    "ocr-default-rec",
)
KOREAN_MODEL_ENV = (
    "MARKITDOWN_PADDLE_OCR_KOREAN_DET_MODEL_DIR",
    "MARKITDOWN_PADDLE_OCR_KOREAN_REC_MODEL_DIR",
    "ocr-korean-det",
    "ocr-korean-rec",
)


def fail(message: str, code: int = 2) -> int:
    print(message, file=sys.stderr)
    return code


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Official MARKITDOWN_PADDLE_OCR_CMD wrapper"
    )
    parser.add_argument("--batch-json", required=True)
    parser.add_argument("--result-json", required=True)
    return parser.parse_args()


def mapped_language(language: str | None) -> str | None:
    if language is None:
        return None
    trimmed = language.strip()
    if not trimmed:
        return None
    return LANGUAGE_ALIASES.get(trimmed, trimmed)


def require_stable_runtime_env() -> list[str]:
    diagnostics = []
    for key, expected in REQUIRED_RUNTIME_ENV.items():
        os.environ[key] = expected
        value = expected
        diagnostics.append(f"{key}={value}")
    return diagnostics


def load_metadata(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise RuntimeError(f"managed model metadata is missing: {path}")
    metadata: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        metadata[key] = value
    return metadata


def validate_managed_model_dir(path: Path, expected_key: str) -> dict[str, str]:
    if not path.is_dir():
        raise RuntimeError(f"managed model directory does not exist: {path}")
    metadata = load_metadata(path / MODEL_METADATA_NAME)
    if metadata.get("MODEL_FAMILY") != "paddle":
        raise RuntimeError(f"managed model is not a Paddle model: {path}")
    if metadata.get("MODEL_KEY") != expected_key:
        raise RuntimeError(
            f"managed model key mismatch for {path}: expected {expected_key!r}, got {metadata.get('MODEL_KEY')!r}"
        )
    for required_name in MODEL_REQUIRED_FILES:
        if not (path / required_name).is_file():
            raise RuntimeError(
                f"managed model directory is missing required file `{required_name}`: {path}"
            )
    return metadata


def resolve_model_bundle(language: str | None) -> tuple[Path, Path, list[str]]:
    det_env, rec_env, det_key, rec_key = (
        KOREAN_MODEL_ENV if language == "korean" else DEFAULT_MODEL_ENV
    )
    det_raw = os.environ.get(det_env, "").strip()
    rec_raw = os.environ.get(rec_env, "").strip()
    if not det_raw or not rec_raw:
        raise RuntimeError(
            "managed Paddle model directories are not configured; run ./tools/env/optional_deps.sh install accurate"
        )
    det_dir = Path(det_raw)
    rec_dir = Path(rec_raw)
    det_meta = validate_managed_model_dir(det_dir, det_key)
    rec_meta = validate_managed_model_dir(rec_dir, rec_key)
    diagnostics = [
        f"det_model_id={det_meta.get('MODEL_ID', '')}",
        f"det_model_sha256={det_meta.get('ARCHIVE_SHA256', '')}",
        f"det_model_dir={det_dir}",
        f"rec_model_id={rec_meta.get('MODEL_ID', '')}",
        f"rec_model_sha256={rec_meta.get('ARCHIVE_SHA256', '')}",
        f"rec_model_dir={rec_dir}",
    ]
    return det_dir, rec_dir, diagnostics


def read_image_size(image_path: str) -> tuple[float | None, float | None]:
    try:
        from PIL import Image

        with Image.open(image_path) as image:
            width, height = image.size
        return float(width), float(height)
    except Exception:
        return None, None


def load_paddle():
    for key, value in PADDLE_ENV.items():
        os.environ[key] = value
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
    det_model_dir, rec_model_dir, diagnostics = resolve_model_bundle(language)
    kwargs = {
        **PADDLE_INIT_KWARGS,
        "text_detection_model_dir": str(det_model_dir),
        "text_recognition_model_dir": str(rec_model_dir),
    }
    diagnostics = [
        *diagnostics,
        f"init_kwargs={json.dumps(PADDLE_INIT_KWARGS, ensure_ascii=True, sort_keys=True)}",
    ]
    try:
        return paddle_ocr_cls(**kwargs), diagnostics
    except TypeError:
        legacy_kwargs = {
            "text_detection_model_dir": str(det_model_dir),
            "text_recognition_model_dir": str(rec_model_dir),
        }
        try:
            return paddle_ocr_cls(use_angle_cls=True, **legacy_kwargs), diagnostics
        except TypeError:
            return paddle_ocr_cls(**legacy_kwargs), diagnostics


def predict_pages(engine, image_path: str):
    if not hasattr(engine, "predict"):
        return None
    kwargs = dict(PADDLE_PREDICT_KWARGS)
    try:
        return engine.predict(image_path, **kwargs)
    except TypeError:
        return engine.predict(image_path)


def normalize_predict_pages(raw_result):
    if raw_result is None:
        return []
    if not isinstance(raw_result, list):
        return []

    pages = []
    for page in raw_result:
        if hasattr(page, "json"):
            page = page.json
        if not isinstance(page, dict):
            continue
        page_data = page.get("res") if isinstance(page.get("res"), dict) else page
        texts = page_data.get("rec_texts")
        if not isinstance(texts, list):
            continue
        scores = page_data.get("rec_scores")
        if not isinstance(scores, list):
            scores = []
        polys = page_data.get("dt_polys")
        if not isinstance(polys, list):
            polys = page_data.get("rec_polys")
        if not isinstance(polys, list):
            polys = []
        pages.append(
            {
                "texts": texts,
                "scores": scores,
                "polys": polys,
            }
        )
    return pages


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


def page_from_predict_result(
    page_index: int,
    image_path: str,
    language: str | None,
    page_result,
):
    width, height = read_image_size(image_path)
    blocks = []
    texts = page_result.get("texts") or []
    scores = page_result.get("scores") or []
    polys = page_result.get("polys") or []

    for block_index, text in enumerate(texts):
        text = str(text).strip()
        if not text:
            continue
        confidence = line_confidence(
            scores[block_index] if block_index < len(scores) else None
        )
        bbox = line_bbox(polys[block_index]) if block_index < len(polys) else None
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


def load_request(request_path: Path) -> dict:
    try:
        payload = json.loads(request_path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise RuntimeError(f"failed to read batch request JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise RuntimeError("batch request JSON root must be an object")
    if payload.get("provider") != "paddle_ocr":
        raise RuntimeError("batch request provider must be `paddle_ocr`")
    if payload.get("version") != "v2":
        raise RuntimeError("batch request version must be `v2`")
    jobs = payload.get("jobs")
    if not isinstance(jobs, list) or not jobs:
        raise RuntimeError("batch request must include a non-empty `jobs` array")
    return payload


def run_one_job(engine, requested_language: str | None, image_path: str) -> list[dict]:
    raw_result = predict_pages(engine, image_path)
    predict_pages_result = normalize_predict_pages(raw_result)
    pages = []
    if predict_pages_result:
        for page_index, page_result in enumerate(predict_pages_result):
            page = page_from_predict_result(
                page_index, image_path, requested_language, page_result
            )
            if page is not None:
                pages.append(page)
        return pages

    try:
        raw_result = engine.ocr(image_path, cls=True)
    except TypeError:
        raw_result = engine.ocr(image_path)
    normalized_pages = normalize_lines(raw_result)
    for page_index, page_lines in enumerate(normalized_pages):
        page = page_from_lines(page_index, image_path, requested_language, page_lines)
        if page is not None:
            pages.append(page)
    return pages


def build_job_groups(jobs: list[dict]) -> dict[str, list[dict]]:
    groups: dict[str, list[dict]] = {}
    for job in jobs:
        requested_language = str(job.get("language") or "").strip() or "none"
        groups.setdefault(requested_language, []).append(job)
    return groups


def main() -> int:
    args = parse_args()
    request_path = Path(args.batch_json)
    result_path = Path(args.result_json)
    if not request_path.is_file():
        return fail(f"batch request JSON does not exist: {request_path}")

    try:
        request_payload = load_request(request_path)
        paddleocr_module, paddle_ocr_cls = load_paddle()
        env_diagnostics = require_stable_runtime_env()
    except Exception as exc:
        return fail(f"PaddleOCR wrapper initialization failed: {exc}")

    jobs = request_payload["jobs"]
    grouped_jobs = build_job_groups(jobs)
    engines: dict[str, object] = {}
    engine_diagnostics: dict[str, list[str]] = {}
    job_results: list[dict] = []
    batch_diagnostics = [
        "wrapper=tools/env/wrappers/paddle_ocr_wrapper.py",
        "batch_mode=v2",
        "mkldnn=disabled",
        f"pir_api={os.environ.get('FLAGS_enable_pir_api', 'unset')}",
        f"job_count={len(jobs)}",
        f"predict_kwargs={json.dumps(PADDLE_PREDICT_KWARGS, ensure_ascii=True, sort_keys=True)}",
    ]
    batch_diagnostics.extend(env_diagnostics)

    for language_key, grouped in grouped_jobs.items():
        try:
            wrapper_language = mapped_language(
                None if language_key == "none" else language_key
            )
            engine = engines.get(language_key)
            if engine is None:
                engine, diagnostics = build_engine(paddle_ocr_cls, wrapper_language)
                engines[language_key] = engine
                engine_diagnostics[language_key] = diagnostics
                batch_diagnostics.extend(
                    f"{language_key or 'none'}:{item}" for item in diagnostics
                )
        except Exception as exc:
            for job in grouped:
                job_results.append(
                    {
                        "job_id": str(job.get("job_id") or ""),
                        "status": "error",
                        "error_kind": "engine_init_failed",
                        "error_message": str(exc),
                        "pages": [],
                    }
                )
            continue

        for job in grouped:
            job_id = str(job.get("job_id") or "")
            image_path = str(job.get("image_path") or "")
            requested_language = str(job.get("language") or "").strip() or None
            if not job_id:
                job_results.append(
                    {
                        "job_id": "",
                        "status": "error",
                        "error_kind": "invalid_job",
                        "error_message": "missing job_id",
                        "pages": [],
                    }
                )
                continue
            if not image_path:
                job_results.append(
                    {
                        "job_id": job_id,
                        "status": "error",
                        "error_kind": "invalid_job",
                        "error_message": "missing image_path",
                        "pages": [],
                    }
                )
                continue
            if not Path(image_path).is_file():
                job_results.append(
                    {
                        "job_id": job_id,
                        "status": "error",
                        "error_kind": "missing_image",
                        "error_message": f"input image does not exist: {image_path}",
                        "pages": [],
                    }
                )
                continue
            try:
                pages = run_one_job(engine, requested_language, image_path)
                job_results.append(
                    {
                        "job_id": job_id,
                        "status": "ok" if pages else "empty",
                        "error_kind": None,
                        "error_message": None,
                        "diagnostics": engine_diagnostics.get(language_key, []),
                        "pages": pages,
                    }
                )
            except Exception as exc:
                job_results.append(
                    {
                        "job_id": job_id,
                        "status": "error",
                        "error_kind": "execution_failed",
                        "error_message": str(exc),
                        "diagnostics": engine_diagnostics.get(language_key, []),
                        "pages": [],
                    }
                )

    payload = {
        "provider_name": "paddle_ocr",
        "provider_version": getattr(paddleocr_module, "__version__", None),
        "diagnostics": batch_diagnostics,
        "jobs": job_results,
    }
    try:
        result_path.parent.mkdir(parents=True, exist_ok=True)
        result_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    except Exception as exc:
        return fail(f"failed to write PaddleOCR batch result JSON: {exc}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
