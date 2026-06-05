#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
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

assert_matches_expected() {
  local expected="$1"
  local actual="$2"
  diff -u "$expected" "$actual" >/dev/null || fail "output mismatch: $actual"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

assert_mbtpdf_count_zero() {
  local path="$1"
  assert_file_exists "$path"
  local count
  count="$( (grep -o 'mbtpdf' "$path" || true) | wc -l | tr -d '[:space:]')"
  [[ "$count" == "0" ]] || fail "expected mbtpdf count 0 in $path, got $count"
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
DOCX_INPUT="$ROOT/samples/main_process/docx/metadata/docx_image_alt_title_basic.docx"
XLSX_INPUT="$ROOT/samples/main_process/xlsx/xlsx_formula_cached_values.xlsx"
PDF_INPUT="$ROOT/samples/main_process/pdf/text_simple.pdf"
PDF_EXPECTED="$ROOT/samples/main_process/pdf/expected/text_simple.md"
PDF_META_INPUT="$ROOT/samples/main_process/pdf/metadata/pdf_metadata_uri_link.pdf"
PDF_META_EXPECTED="$ROOT/samples/main_process/pdf/expected/metadata/pdf_metadata_uri_link.md"
PDF_META_JSON_EXPECTED="$ROOT/samples/main_process/pdf/expected/metadata/pdf_metadata_uri_link.metadata.json"
ZIP_INPUT="$ROOT/samples/main_process/zip/zip_basic_structured.zip"
ZIP_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_basic_structured.md"

NO_META_DIR="$OUT_DIR/no_meta"
WITH_META_DIR="$OUT_DIR/with_meta"
STDOUT_DIR="$OUT_DIR/stdout"
mkdir -p "$STDOUT_DIR"

HELP_STDOUT="$STDOUT_DIR/help.txt"
HELP_ALIAS_STDOUT="$STDOUT_DIR/help_alias.txt"
HELP_SHORT_STDOUT="$STDOUT_DIR/help_short.txt"
VERSION_STDOUT="$STDOUT_DIR/version.txt"
VERSION_ALIAS_STDOUT="$STDOUT_DIR/version_alias.txt"
CLI_C="$ROOT/_build/native/debug/build/cli/cli.c"

TXT_NO_META_MD="$NO_META_DIR/txt_plain.md"
TXT_WITH_META_MD="$WITH_META_DIR/txt_plain.md"
DOCX_NO_META_MD="$NO_META_DIR/docx_image_alt_title_basic.md"
DOCX_WITH_META_MD="$WITH_META_DIR/docx_image_alt_title_basic.md"
XLSX_WITH_META_MD="$WITH_META_DIR/xlsx_formula_cached_values.md"
TXT_ALIAS_MD="$NO_META_DIR/txt_plain_alias.md"
PDF_NO_META_MD="$NO_META_DIR/text_simple.md"
PDF_ALIAS_MD="$NO_META_DIR/text_simple_alias.md"
PDF_WITH_META_MD="$WITH_META_DIR/pdf_metadata_uri_link.md"
ZIP_NO_META_MD="$NO_META_DIR/zip_basic_structured.md"
ZIP_ALIAS_MD="$NO_META_DIR/zip_basic_structured_alias.md"

echo "==> top-level help aliases stay local and list product surface"
run_and_capture "$HELP_STDOUT" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$HELP_STDOUT" 'markitdown-mb [normal] [--with-metadata] [--ocr|--no-ocr] [--ocr-lang LANG] <input> [output]'
assert_contains "$HELP_STDOUT" 'Supported normal formats:'
assert_contains "$HELP_STDOUT" 'bundled `pdf` / `zip` components'
assert_contains "$HELP_STDOUT" 'debug'
assert_contains "$HELP_STDOUT" 'bench'
assert_contains "$HELP_STDOUT" 'Image inputs now auto-OCR through convert/vision when local tesseract is available'

run_and_capture "$HELP_ALIAS_STDOUT" run_markitdown_cli help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "help alias should succeed"
assert_contains "$HELP_ALIAS_STDOUT" 'markitdown-mb help | --help | -h'

run_and_capture "$HELP_SHORT_STDOUT" run_markitdown_cli -h
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "-h should succeed"
assert_contains "$HELP_SHORT_STDOUT" 'markitdown-mb version | --version'

echo "==> top-level version aliases stay local and stable"
run_and_capture "$VERSION_STDOUT" run_markitdown_cli --version
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--version should succeed"
assert_contains "$VERSION_STDOUT" 'markitdown-mb 0.3.4'

run_and_capture "$VERSION_ALIAS_STDOUT" run_markitdown_cli version
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "version alias should succeed"
assert_matches_expected "$VERSION_STDOUT" "$VERSION_ALIAS_STDOUT"

echo "==> cli product stays out of vendored pdf closure"
assert_mbtpdf_count_zero "$CLI_C"

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

echo "==> bare normal alias"
run_markitdown_cli "$TXT_INPUT" "$TXT_ALIAS_MD"
assert_file_exists "$TXT_ALIAS_MD"

echo "==> pdf product path without metadata"
run_markitdown_cli normal "$PDF_INPUT" "$PDF_NO_META_MD"
assert_file_exists "$PDF_NO_META_MD"
assert_file_not_exists "$NO_META_DIR/metadata/text_simple.metadata.json"
assert_matches_expected "$PDF_EXPECTED" "$PDF_NO_META_MD"

echo "==> pdf product path with metadata"
run_markitdown_cli normal --with-metadata "$PDF_META_INPUT" "$PDF_WITH_META_MD"
assert_file_exists "$PDF_WITH_META_MD"
assert_file_exists "$WITH_META_DIR/metadata/pdf_metadata_uri_link.metadata.json"
assert_matches_expected "$PDF_META_EXPECTED" "$PDF_WITH_META_MD"
assert_matches_expected "$PDF_META_JSON_EXPECTED" "$WITH_META_DIR/metadata/pdf_metadata_uri_link.metadata.json"

echo "==> bare pdf alias"
run_markitdown_cli "$PDF_INPUT" "$PDF_ALIAS_MD"
assert_file_exists "$PDF_ALIAS_MD"
assert_matches_expected "$PDF_EXPECTED" "$PDF_ALIAS_MD"

echo "==> zip product path"
run_markitdown_cli normal "$ZIP_INPUT" "$ZIP_NO_META_MD"
assert_file_exists "$ZIP_NO_META_MD"
assert_matches_expected "$ZIP_EXPECTED" "$ZIP_NO_META_MD"

echo "==> bare zip alias"
run_markitdown_cli "$ZIP_INPUT" "$ZIP_ALIAS_MD"
assert_file_exists "$ZIP_ALIAS_MD"
assert_matches_expected "$ZIP_EXPECTED" "$ZIP_ALIAS_MD"

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
