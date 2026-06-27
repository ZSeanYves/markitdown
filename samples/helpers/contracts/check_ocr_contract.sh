#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp.sh"
source "$ROOT/samples/helpers/shared/cli_runner.sh"
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

TXT_INPUT="$ROOT/samples/main_process/txt/markdown/txt_plain.txt"
IMAGE_INPUT="$ROOT/samples/fixtures/ocr/tiny_ocr_sample.png"
PDF_INPUT="$ROOT/samples/main_process/pdf/markdown/text_simple.pdf"

echo "==> retired ocr subcommand fails closed through the main cli"
run_and_capture "$OUT_DIR/ocr_retired.txt" run_markitdown_cli ocr "$TXT_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "ocr subcommand should fail closed"
assert_contains "$OUT_DIR/ocr_retired.txt" 'unsupported subcommand in this build: ocr'

echo "==> image input is not exposed through the main cli"
run_and_capture "$OUT_DIR/image_auto.txt" run_markitdown_cli "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image input should fail closed through main cli"
assert_contains "$OUT_DIR/image_auto.txt" 'unsupported format'
assert_contains "$OUT_DIR/image_auto.txt" 'png'
assert_contains "$OUT_DIR/image_auto.txt" 'this build'
assert_contains "$OUT_DIR/image_auto.txt" 'image OCR is not enabled'

echo "==> explicit ocr flags still parse, but required contract does not depend on local provider availability"
run_and_capture "$OUT_DIR/image_force.txt" run_markitdown_cli --ocr "$IMAGE_INPUT"
if [[ "$CAPTURED_STATUS" -eq 0 ]]; then
  if [[ ! -s "$OUT_DIR/image_force.txt" ]]; then
    fail "image --ocr succeeded but produced empty output"
  fi
else
  if ! grep -Fq 'tesseract' "$OUT_DIR/image_force.txt" && ! grep -Fq 'OCR provider' "$OUT_DIR/image_force.txt" && ! grep -Fq 'not configured' "$OUT_DIR/image_force.txt"; then
    fail "image --ocr failure should explain OCR provider availability"
  fi
fi

run_and_capture "$OUT_DIR/image_lang.txt" run_markitdown_cli --ocr-lang eng "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --ocr-lang should fail closed through main cli"
assert_contains "$OUT_DIR/image_lang.txt" '--ocr-lang requires --ocr'

run_and_capture "$OUT_DIR/image_no_ocr.txt" run_markitdown_cli --no-ocr "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --no-ocr should fail closed through main cli"
assert_contains "$OUT_DIR/image_no_ocr.txt" 'unsupported format'
assert_contains "$OUT_DIR/image_no_ocr.txt" 'OCR is disabled'

run_and_capture "$OUT_DIR/image_force_lang.txt" run_markitdown_cli --ocr --ocr-lang eng "$IMAGE_INPUT"
if [[ "$CAPTURED_STATUS" -eq 0 ]]; then
  if [[ ! -s "$OUT_DIR/image_force_lang.txt" ]]; then
    fail "image --ocr --ocr-lang succeeded but produced empty output"
  fi
else
  if ! grep -Fq 'tesseract' "$OUT_DIR/image_force_lang.txt" && ! grep -Fq 'OCR provider' "$OUT_DIR/image_force_lang.txt" && ! grep -Fq 'not configured' "$OUT_DIR/image_force_lang.txt"; then
    fail "image --ocr --ocr-lang failure should explain OCR provider availability"
  fi
  assert_contains "$OUT_DIR/image_force_lang.txt" 'eng'
fi

run_and_capture "$OUT_DIR/image_conflict.txt" run_markitdown_cli --ocr --no-ocr "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --ocr --no-ocr should fail closed through main cli"
assert_contains "$OUT_DIR/image_conflict.txt" 'cannot combine --ocr and --no-ocr'

echo "==> pdf ocr flags also stay fail-closed"
run_and_capture "$OUT_DIR/pdf_force.txt" run_markitdown_cli --ocr --ocr-lang eng "$PDF_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "pdf --ocr should fail closed through main cli"
assert_contains "$OUT_DIR/pdf_force.txt" 'PDF OCR is not supported'
assert_contains "$OUT_DIR/pdf_force.txt" 'scanned/image-only PDFs'

echo "NO IMPLICIT OCR CONTRACT PASSED"
