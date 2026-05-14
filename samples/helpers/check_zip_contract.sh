#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"
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

ZIP_INPUT="$ROOT/samples/main_process/zip/zip_basic_structured.zip"
ZIP_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_basic_structured.md"
ZIP_OUT="$OUT_DIR/zip_basic_structured.md"

echo "==> direct zip markdown output"
run_markitdown_zip_cli "$ZIP_INPUT" "$ZIP_OUT"
assert_file_exists "$ZIP_OUT"
assert_matches_expected "$ZIP_EXPECTED" "$ZIP_OUT"

echo "ZIP CONTRACT PASSED"
