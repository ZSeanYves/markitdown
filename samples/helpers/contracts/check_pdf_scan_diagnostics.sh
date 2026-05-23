#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "pdf_scan_diagnostics")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_debug_cli
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
  grep -q "$needle" "$path" || fail "expected $path to contain: $needle"
}

run_debug_json() {
  local input="$1"
  local out="$2"
  run_markitdown_debug_cli --json "$input" > "$out"
}

TEXT_INPUT="$ROOT/samples/main_process/pdf/text_simple.pdf"
LOW_SIGNAL_INPUT="$ROOT/samples/main_process/pdf/assets/pdf_image_xobject.pdf"

echo "==> pdf scan diagnostics text pdf"
run_debug_json "$TEXT_INPUT" "$OUT_DIR/text_simple.json"
assert_contains "$OUT_DIR/text_simple.json" '"detected_format": "pdf"'
assert_contains "$OUT_DIR/text_simple.json" '"name": "pdf_backend"'
assert_contains "$OUT_DIR/text_simple.json" '"ocr_mode": "native"'
assert_contains "$OUT_DIR/text_simple.json" '"ocr_used": false'
assert_contains "$OUT_DIR/text_simple.json" '"text_signal_level": "normal"'
assert_contains "$OUT_DIR/text_simple.json" '"has_embedded_text": true'
assert_contains "$OUT_DIR/text_simple.json" '"has_page_images": false'
assert_contains "$OUT_DIR/text_simple.json" '"image_only": false'
assert_contains "$OUT_DIR/text_simple.json" '"ocr_recommended": false'

echo "==> pdf scan diagnostics low-text image-heavy pdf"
run_debug_json "$LOW_SIGNAL_INPUT" "$OUT_DIR/pdf_image_xobject.json"
assert_contains "$OUT_DIR/pdf_image_xobject.json" '"detected_format": "pdf"'
assert_contains "$OUT_DIR/pdf_image_xobject.json" '"name": "pdf_backend"'
assert_contains "$OUT_DIR/pdf_image_xobject.json" '"ocr_mode": "native"'
assert_contains "$OUT_DIR/pdf_image_xobject.json" '"ocr_used": false'
assert_contains "$OUT_DIR/pdf_image_xobject.json" '"text_signal_level": "low"'
assert_contains "$OUT_DIR/pdf_image_xobject.json" '"has_page_images": true'
assert_contains "$OUT_DIR/pdf_image_xobject.json" '"page_image_count": 1'
assert_contains "$OUT_DIR/pdf_image_xobject.json" '"ocr_recommended": true'

echo "PDF SCAN DIAGNOSTICS CONTRACT PASSED"
