#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "pdf_contract")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_pdf_cli
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

assert_dir_exists() {
  local path="$1"
  [[ -d "$path" ]] || fail "expected directory missing: $path"
}

assert_matches_expected() {
  local expected="$1"
  local actual="$2"
  diff -u "$expected" "$actual" >/dev/null || fail "output mismatch: $actual"
}

TEXT_INPUT="$ROOT/samples/main_process/pdf/text_simple.pdf"
TEXT_EXPECTED="$ROOT/samples/main_process/pdf/expected/text_simple.md"
META_INPUT="$ROOT/samples/main_process/pdf/metadata/pdf_metadata_uri_link.pdf"
META_EXPECTED="$ROOT/samples/main_process/pdf/expected/metadata/pdf_metadata_uri_link.md"
META_JSON_EXPECTED="$ROOT/samples/main_process/pdf/expected/metadata/pdf_metadata_uri_link.metadata.json"
ASSET_INPUT="$ROOT/samples/main_process/pdf/assets/pdf_image_xobject.pdf"
ASSET_EXPECTED="$ROOT/samples/main_process/pdf/expected/assets/pdf_image_xobject.md"

TEXT_OUT="$OUT_DIR/text_simple.md"
META_OUT="$OUT_DIR/pdf_metadata_uri_link.md"
ASSET_OUT="$OUT_DIR/pdf_image_xobject.md"

echo "==> direct pdf markdown output"
run_markitdown_pdf_cli "$TEXT_INPUT" "$TEXT_OUT"
assert_file_exists "$TEXT_OUT"
assert_matches_expected "$TEXT_EXPECTED" "$TEXT_OUT"

echo "==> direct pdf metadata sidecar output"
run_markitdown_pdf_cli --with-metadata "$META_INPUT" "$META_OUT"
assert_file_exists "$META_OUT"
assert_file_exists "$OUT_DIR/metadata/pdf_metadata_uri_link.metadata.json"
assert_matches_expected "$META_EXPECTED" "$META_OUT"
assert_matches_expected "$META_JSON_EXPECTED" "$OUT_DIR/metadata/pdf_metadata_uri_link.metadata.json"

echo "==> direct pdf asset output"
run_markitdown_pdf_cli "$ASSET_INPUT" "$ASSET_OUT"
assert_file_exists "$ASSET_OUT"
assert_dir_exists "$OUT_DIR/assets"
assert_matches_expected "$ASSET_EXPECTED" "$ASSET_OUT"

echo "PDF CONTRACT PASSED"
