#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp.sh"
source "$ROOT/samples/helpers/shared/cli_runner.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "direct_image_ocr_contract")"

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

echo "==> direct image input is formally exposed through the main cli"
run_and_capture "$OUT_DIR/image_auto.txt" run_markitdown_cli "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "image input should succeed through main cli"
assert_contains "$OUT_DIR/image_auto.txt" 'MoonBit OCR'
assert_contains "$OUT_DIR/image_auto.txt" 'Sample 123'

echo "==> explicit ocr flags remain accepted"
run_and_capture "$OUT_DIR/image_force.txt" run_markitdown_cli --ocr "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "image --ocr should succeed"
assert_contains "$OUT_DIR/image_force.txt" 'MoonBit OCR'

run_and_capture "$OUT_DIR/image_lang.txt" run_markitdown_cli --ocr-lang eng "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "image --ocr-lang should succeed for direct image input"
assert_contains "$OUT_DIR/image_lang.txt" 'MoonBit OCR'

run_and_capture "$OUT_DIR/image_no_ocr.txt" run_markitdown_cli --no-ocr "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --no-ocr should fail closed through main cli"
assert_contains "$OUT_DIR/image_no_ocr.txt" 'image input conversion is not enabled'
assert_contains "$OUT_DIR/image_no_ocr.txt" 'OCR is disabled'

run_and_capture "$OUT_DIR/image_force_lang.txt" run_markitdown_cli --ocr --ocr-lang eng "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "image --ocr --ocr-lang should succeed"
assert_contains "$OUT_DIR/image_force_lang.txt" 'MoonBit OCR'

run_and_capture "$OUT_DIR/image_conflict.txt" run_markitdown_cli --ocr --no-ocr "$IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "image --ocr --no-ocr should fail closed through main cli"
assert_contains "$OUT_DIR/image_conflict.txt" 'cannot combine --ocr and --no-ocr'

echo "==> pdf ocr flags use the dependency-backed pdf OCR route"
run_and_capture "$OUT_DIR/pdf_force.txt" run_markitdown_cli --ocr --ocr-lang eng "$PDF_INPUT"
if [[ "$CAPTURED_STATUS" -ne 0 ]]; then
  assert_contains "$OUT_DIR/pdf_force.txt" 'pdftoppm'
fi

echo "DIRECT IMAGE OCR CONTRACT PASSED"
