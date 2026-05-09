#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "cli_contract")"

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

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file missing: $path"
}

assert_dir_exists() {
  local path="$1"
  [[ -d "$path" ]] || fail "expected directory missing: $path"
}

assert_file_not_exists() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "unexpected path exists: $path"
}

TXT_INPUT="$ROOT/samples/main_process/txt/txt_plain.txt"
DOCX_INPUT="$ROOT/samples/main_process/docx/metadata/docx_image_alt_title_basic.docx"
XLSX_INPUT="$ROOT/samples/main_process/xlsx/xlsx_formula_cached_values.xlsx"

NO_META_DIR="$OUT_DIR/no_meta"
WITH_META_DIR="$OUT_DIR/with_meta"
STDOUT_DIR="$OUT_DIR/stdout"
mkdir -p "$STDOUT_DIR"

TXT_NO_META_MD="$NO_META_DIR/txt_plain.md"
TXT_WITH_META_MD="$WITH_META_DIR/txt_plain.md"
DOCX_NO_META_MD="$NO_META_DIR/docx_image_alt_title_basic.md"
DOCX_WITH_META_MD="$WITH_META_DIR/docx_image_alt_title_basic.md"
XLSX_WITH_META_MD="$WITH_META_DIR/xlsx_formula_cached_values.md"

echo "==> normal without metadata"
run_markitdown_cli normal "$TXT_INPUT" "$TXT_NO_META_MD"
assert_file_exists "$TXT_NO_META_MD"
assert_file_not_exists "$NO_META_DIR/metadata/txt_plain.metadata.json"

echo "==> normal with metadata"
run_markitdown_cli normal --with-metadata "$TXT_INPUT" "$TXT_WITH_META_MD"
assert_file_exists "$TXT_WITH_META_MD"
assert_file_exists "$WITH_META_DIR/metadata/txt_plain.metadata.json"

echo "==> normal assets without metadata"
run_markitdown_cli normal "$DOCX_INPUT" "$DOCX_NO_META_MD"
assert_file_exists "$DOCX_NO_META_MD"
assert_file_not_exists "$NO_META_DIR/metadata/docx_image_alt_title_basic.metadata.json"
assert_dir_exists "$NO_META_DIR/assets"

echo "==> normal assets with metadata"
run_markitdown_cli normal --with-metadata "$DOCX_INPUT" "$DOCX_WITH_META_MD"
assert_file_exists "$DOCX_WITH_META_MD"
assert_file_exists "$WITH_META_DIR/metadata/docx_image_alt_title_basic.metadata.json"
assert_dir_exists "$WITH_META_DIR/assets"

echo "==> xlsx with metadata"
run_markitdown_cli normal --with-metadata "$XLSX_INPUT" "$XLSX_WITH_META_MD"
assert_file_exists "$XLSX_WITH_META_MD"
assert_file_exists "$WITH_META_DIR/metadata/xlsx_formula_cached_values.metadata.json"

echo "==> stdout contract"
STDOUT_MD="$STDOUT_DIR/stdout.md"
(
  cd "$STDOUT_DIR"
  run_markitdown_cli normal "$DOCX_INPUT" > "$STDOUT_MD"
)
assert_file_exists "$STDOUT_MD"
assert_file_not_exists "$STDOUT_DIR/out"
assert_file_not_exists "$STDOUT_DIR/metadata"
assert_file_not_exists "$STDOUT_DIR/assets"

echo "CLI CONTRACT PASSED"
