#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FIXTURE_PNG="$ROOT/samples/fixtures/ocr/tiny_ocr_sample.png"
FIXTURE_EXPECTED="$ROOT/samples/fixtures/ocr/tiny_ocr_sample.expected.txt"
TMP_DIR="$ROOT/.tmp/vision_tesseract_tsv_signal_optional"
TSV_BASE="$TMP_DIR/tiny_ocr_sample"
TSV_PATH="${TSV_BASE}.tsv"
SUMMARY_PATH="$TMP_DIR/summary.txt"
PREVIEW_PATH="$TMP_DIR/preview.md"

mkdir -p "$TMP_DIR"

if [[ ! -f "$FIXTURE_PNG" || ! -f "$FIXTURE_EXPECTED" ]]; then
  echo "VISION TESSERACT TSV SIGNAL SMOKE SKIPPED: tiny OCR fixture missing"
  exit 0
fi

if ! command -v tesseract >/dev/null 2>&1; then
  echo "VISION TESSERACT TSV SIGNAL SMOKE SKIPPED: tesseract not installed"
  exit 0
fi

rm -f "$TSV_PATH" "$SUMMARY_PATH" "$PREVIEW_PATH"

echo "[vision-smoke] generating TSV from tiny OCR fixture"
tesseract "$FIXTURE_PNG" "$TSV_BASE" tsv >/dev/null 2>&1 || {
  echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: tesseract TSV generation failed"
  exit 1
}

if [[ ! -f "$TSV_PATH" ]]; then
  echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: missing TSV output: $TSV_PATH"
  exit 1
fi

echo "[vision-smoke] parsing TSV into OCRPageModel summary"
moon run convert/vision/tsv_summary_tool -- --tsv "$TSV_PATH" --output "$SUMMARY_PATH" >/dev/null

if [[ ! -f "$SUMMARY_PATH" ]]; then
  echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: missing summary output: $SUMMARY_PATH"
  exit 1
fi

grep -Fq 'provider=tesseract-tsv' "$SUMMARY_PATH" || {
  echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: missing provider summary"
  exit 1
}

grep -Fq 'source_kind=tesseract-tsv' "$SUMMARY_PATH" || {
  echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: missing source_kind summary"
  exit 1
}

grep -Eq '^lines=[1-9][0-9]*$' "$SUMMARY_PATH" || {
  echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: expected positive line count"
  exit 1
}

grep -Eq '^words=[1-9][0-9]*$' "$SUMMARY_PATH" || {
  echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: expected positive word count"
  exit 1
}

FIRST_EXPECTED_LINE="$(head -n 1 "$FIXTURE_EXPECTED" | tr -d '\r')"
if [[ -n "$FIRST_EXPECTED_LINE" ]]; then
  grep -Fq "$FIRST_EXPECTED_LINE" "$SUMMARY_PATH" || {
    echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: expected summary text to mention '$FIRST_EXPECTED_LINE'"
    exit 1
  }
fi

echo "[vision-smoke] rendering OCR layout markdown preview"
moon run convert/vision/tsv_preview_tool -- --tsv "$TSV_PATH" --output "$PREVIEW_PATH" >/dev/null

if [[ ! -f "$PREVIEW_PATH" ]]; then
  echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: missing preview output: $PREVIEW_PATH"
  exit 1
fi

if [[ -n "$FIRST_EXPECTED_LINE" ]]; then
  grep -Fq "$FIRST_EXPECTED_LINE" "$PREVIEW_PATH" || {
    echo "VISION TESSERACT TSV SIGNAL SMOKE FAILED: expected preview to mention '$FIRST_EXPECTED_LINE'"
    exit 1
  }
fi

echo "VISION TESSERACT TSV SIGNAL SMOKE PASSED"
echo "  fixture=$FIXTURE_PNG"
echo "  tsv=$TSV_PATH"
echo "  summary=$SUMMARY_PATH"
echo "  preview=$PREVIEW_PATH"
