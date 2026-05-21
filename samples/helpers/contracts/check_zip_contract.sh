#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "zip_contract")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_zip_cli
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

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file missing: $path"
}

assert_matches_expected() {
  local expected="$1"
  local actual="$2"
  diff -u "$expected" "$actual" >/dev/null || fail "output mismatch: $actual"
}

assert_mbtpdf_count_zero() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file missing: $path"
  local count
  count="$( (grep -o 'mbtpdf' "$path" || true) | wc -l | tr -d '[:space:]')"
  [[ "$count" == "0" ]] || fail "expected mbtpdf count 0 in $path, got $count"
}

ZIP_INPUT="$ROOT/samples/main_process/zip/zip_basic_structured.zip"
ZIP_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_basic_structured.md"
ZIP_OUT="$OUT_DIR/zip_basic_structured.md"
ZIP_C="$ROOT/_build/native/debug/build/zip/zip.c"

echo "==> zip product stays out of vendored pdf closure"
assert_mbtpdf_count_zero "$ZIP_C"

echo "==> direct zip markdown output"
run_markitdown_zip_cli "$ZIP_INPUT" "$ZIP_OUT"
assert_file_exists "$ZIP_OUT"
assert_matches_expected "$ZIP_EXPECTED" "$ZIP_OUT"

echo "ZIP CONTRACT PASSED"
