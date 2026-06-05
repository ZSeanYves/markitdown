#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "no_implicit_ocr_contract")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_cli
echo "runner: $CLI_RUNNER_KIND"
echo "runner_class: $(runner_class_for_kind "$CLI_RUNNER_KIND")"
echo "runner_command: $(markitdown_runner_command_prefix)"
if [[ -n "${CLI_RUNNER_NOTE:-}" ]]; then
  echo "runner-note: $CLI_RUNNER_NOTE"
fi

fail() {
  echo "[fail] $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

TXT_INPUT="$ROOT/samples/main_process/txt/txt_plain.txt"
TXT_OUTPUT="$OUT_DIR/txt_plain.md"
PDF_INPUT="$ROOT/samples/main_process/pdf/text_simple.pdf"
PDF_OUTPUT="$OUT_DIR/text_simple.md"
IMAGE_INPUT="$ROOT/samples/fixtures/ocr/tiny_ocr_sample.png"
tesseract_has_lang() {
  local lang="$1"
  if ! tesseract_available; then
    return 1
  fi
  tesseract --list-langs 2>/dev/null | grep -Fxq "$lang"
}

tesseract_available() {
  if command -v tesseract >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

echo "==> normal path does not auto ocr"
run_markitdown_cli normal "$TXT_INPUT" "$TXT_OUTPUT"
[[ -f "$TXT_OUTPUT" ]] || fail "expected normal path output"
if grep -Fq 'OCRPageModel' "$TXT_OUTPUT"; then
  fail "normal path should not emit OCR rebuild text"
fi

echo "==> retired ocr surface fails closed"
run_and_capture "$OUT_DIR/ocr_retired.txt" run_markitdown_cli ocr "$TXT_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "retired ocr surface should fail closed"
assert_contains "$OUT_DIR/ocr_retired.txt" 'ocr product surface has been retired in this build'

echo "==> image input default auto-ocr executes when tesseract is available"
run_and_capture "$OUT_DIR/image_auto.txt" run_markitdown_cli "$IMAGE_INPUT"
if tesseract_available; then
  [[ "$CAPTURED_STATUS" -eq 0 ]] || fail "image auto-ocr should succeed when tesseract is available"
  assert_contains "$OUT_DIR/image_auto.txt" 'MoonBit OCR'
  assert_contains "$OUT_DIR/image_auto.txt" 'Sample 123'
else
  [[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image auto-ocr should fail clearly without tesseract"
  assert_contains "$OUT_DIR/image_auto.txt" 'Image OCR failed: tesseract executable was not available or failed.'
fi

echo "==> image input explicit --ocr executes when tesseract is available"
run_and_capture "$OUT_DIR/image_force.txt" run_markitdown_cli --ocr "$IMAGE_INPUT"
if tesseract_available; then
  [[ "$CAPTURED_STATUS" -eq 0 ]] || fail "image --ocr should succeed when tesseract is available"
  assert_contains "$OUT_DIR/image_force.txt" 'MoonBit OCR'
  assert_contains "$OUT_DIR/image_force.txt" 'Sample 123'
else
  [[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --ocr should fail clearly without tesseract"
  assert_contains "$OUT_DIR/image_force.txt" 'Image OCR failed: tesseract executable was not available or failed.'
fi

echo "==> image input explicit --ocr-lang uses requested tesseract language when available"
run_and_capture "$OUT_DIR/image_lang.txt" run_markitdown_cli --ocr-lang eng "$IMAGE_INPUT"
if tesseract_available && tesseract_has_lang eng; then
  [[ "$CAPTURED_STATUS" -eq 0 ]] || fail "image --ocr-lang eng should succeed when tesseract eng is available"
  assert_contains "$OUT_DIR/image_lang.txt" 'MoonBit OCR'
  assert_contains "$OUT_DIR/image_lang.txt" 'Sample 123'
else
  [[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --ocr-lang eng should fail clearly without usable tesseract eng data"
  assert_contains "$OUT_DIR/image_lang.txt" 'Image OCR failed: tesseract executable was not available or failed.'
fi

echo "==> image input explicit --no-ocr fails because no native image path exists"
run_and_capture "$OUT_DIR/image_disable.txt" run_markitdown_cli --no-ocr "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --no-ocr should fail closed"
assert_contains "$OUT_DIR/image_disable.txt" 'OCR disabled for image input; no native image-to-markdown conversion is available.'

echo "==> image input explicit --no-ocr rejects ocr language override"
run_and_capture "$OUT_DIR/image_disable_lang.txt" run_markitdown_cli --no-ocr --ocr-lang eng "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --no-ocr --ocr-lang should fail closed"
assert_contains "$OUT_DIR/image_disable_lang.txt" '--ocr-lang cannot be used when --no-ocr is set'

echo "==> conflicting ocr policy flags fail clearly"
run_and_capture "$OUT_DIR/ocr_conflict.txt" run_markitdown_cli --ocr --no-ocr "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "conflicting OCR flags should fail"
assert_contains "$OUT_DIR/ocr_conflict.txt" '--ocr and --no-ocr cannot be used together'

echo "==> missing ocr language value fails clearly"
run_and_capture "$OUT_DIR/ocr_lang_missing.txt" run_markitdown_cli "$IMAGE_INPUT" --ocr-lang
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "--ocr-lang without value should fail"
assert_contains "$OUT_DIR/ocr_lang_missing.txt" 'missing value for --ocr-lang'

echo "==> forcing ocr on non-image documents fails closed"
run_and_capture "$OUT_DIR/txt_force.txt" run_markitdown_cli --ocr "$TXT_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "non-image --ocr should fail closed"
assert_contains "$OUT_DIR/txt_force.txt" 'OCR is only recognized for image inputs in this build; PDF OCR is not wired.'

echo "==> non-image ocr language flag fails clearly"
run_and_capture "$OUT_DIR/txt_lang.txt" run_markitdown_cli "$TXT_INPUT" --ocr-lang eng
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "non-image --ocr-lang should fail closed"
assert_contains "$OUT_DIR/txt_lang.txt" '--ocr-lang can only be used with image OCR in this build'

echo "==> forcing ocr on pdf fails closed"
run_and_capture "$OUT_DIR/pdf_force.txt" run_markitdown_cli --ocr --ocr-lang eng "$PDF_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "pdf --ocr should fail closed"
assert_contains "$OUT_DIR/pdf_force.txt" 'PDF OCR is not wired in this build. Image OCR will use the main CLI OCR path; PDF OCR will require an explicit PDF OCR provider.'

echo "==> normal pdf path stays native and non-ocr"
run_markitdown_cli normal "$PDF_INPUT" "$PDF_OUTPUT"
[[ -f "$PDF_OUTPUT" ]] || fail "expected pdf normal path output"
if grep -Fq 'OCRPageModel' "$PDF_OUTPUT"; then
  fail "normal pdf path should not emit OCR rebuild text"
fi

echo "NO IMPLICIT OCR CONTRACT PASSED"
