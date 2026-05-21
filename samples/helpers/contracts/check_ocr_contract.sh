#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "ocr_contract")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_ocr_cli
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
  grep -Fq "$needle" "$path" || fail "expected $path to contain: $needle"
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

FAKE_IMAGE="$OUT_DIR/page.png"
printf 'fake image\n' > "$FAKE_IMAGE"
TXT_INPUT="$ROOT/samples/main_process/txt/txt_plain.txt"
TXT_OUTPUT="$OUT_DIR/txt_plain.md"

echo "==> ocr stub reports rebuild boundary"
run_and_capture "$OUT_DIR/ocr_stub.txt" run_markitdown_ocr_cli "$FAKE_IMAGE"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "ocr stub should exit successfully"
assert_contains "$OUT_DIR/ocr_stub.txt" 'OCR is being rebuilt around OCRPageModel; current OCR provider execution is not wired in this build.'

echo "==> normal path does not auto ocr"
resolve_markitdown_cli
run_markitdown_cli normal "$TXT_INPUT" "$TXT_OUTPUT"
[[ -f "$TXT_OUTPUT" ]] || fail "expected normal path output"
if grep -Fq 'OCRPageModel' "$TXT_OUTPUT"; then
  fail "normal path should not emit OCR rebuild text"
fi

echo "OCR CONTRACT PASSED"
