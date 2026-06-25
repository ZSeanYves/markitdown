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

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

TXT_INPUT="$ROOT/samples/main_process/txt/txt_plain.txt"
TXT_EXPECTED="$ROOT/samples/main_process/txt/expected/txt_plain.md"
CSV_INPUT="$ROOT/samples/main_process/csv/csv_basic.csv"
CSV_EXPECTED="$ROOT/samples/main_process/csv/expected/csv_basic.md"
TSV_INPUT="$ROOT/samples/main_process/tsv/tsv_basic.tsv"
TSV_EXPECTED="$ROOT/samples/main_process/tsv/expected/tsv_basic.md"
DOCX_INPUT="$ROOT/samples/main_process/docx/metadata/docx_image_alt_title_basic.docx"
DOCX_EXPECTED="$ROOT/samples/main_process/docx/expected/metadata/docx_image_alt_title_basic.md"
PPTX_INPUT="$ROOT/samples/main_process/pptx/pptx_hidden_slide_basic.pptx"
XLSX_INPUT="$ROOT/samples/main_process/xlsx/sheet_simple.xlsx"
ZIP_INPUT="$ROOT/samples/main_process/zip/zip_basic_structured.zip"
ZIP_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_basic_structured.md"
EPUB_INPUT="$ROOT/samples/main_process/epub/epub_basic_package.epub"
PDF_INPUT="$ROOT/samples/main_process/pdf/root_native_text_baseline.pdf"
MD_INPUT="$ROOT/samples/main_process/markdown/markdown_heading.md"
MARKDOWN_INPUT="$ROOT/samples/main_process/markdown/markdown_basic_heading_paragraph.md"
MARKDOWN_DOT_INPUT="$ROOT/samples/main_process/markdown/markdown_frontmatter_passthrough.markdown"
HTML_INPUT="$ROOT/samples/main_process/html/html_simple.html"
JSON_INPUT="$ROOT/samples/main_process/json/json_object_basic.json"
JSON_EXPECTED="$ROOT/samples/main_process/json/expected/json_object_basic.md"
JSONL_INPUT="$ROOT/samples/main_process/jsonl/jsonl_records_basic.jsonl"
JSONL_EXPECTED="$ROOT/samples/main_process/jsonl/expected/jsonl_records_basic.md"
NDJSON_INPUT="$ROOT/samples/main_process/ndjson/ndjson_records_basic.ndjson"
NDJSON_EXPECTED="$ROOT/samples/main_process/ndjson/expected/ndjson_records_basic.md"
XML_INPUT="$ROOT/samples/main_process/xml/xml_basic.xml"
XML_EXPECTED="$ROOT/samples/main_process/xml/expected/xml_basic.md"
YAML_INPUT="$ROOT/samples/main_process/yaml/yaml_mapping_basic.yaml"
YAML_EXPECTED="$ROOT/samples/main_process/yaml/expected/yaml_mapping_basic.md"
MARKDOWN_EXPECTED="$ROOT/samples/main_process/markdown/expected/markdown_basic_heading_paragraph.md"
MARKDOWN_DOT_EXPECTED="$ROOT/samples/main_process/markdown/expected/markdown_frontmatter_passthrough.md"

NO_META_DIR="$OUT_DIR/no_meta"
STDOUT_DIR="$OUT_DIR/stdout"
mkdir -p "$STDOUT_DIR"

HELP_STDOUT="$STDOUT_DIR/help.txt"
HELP_ALIAS_STDOUT="$STDOUT_DIR/help_alias.txt"
HELP_SHORT_STDOUT="$STDOUT_DIR/help_short.txt"
VERSION_STDOUT="$STDOUT_DIR/version.txt"
VERSION_ALIAS_STDOUT="$STDOUT_DIR/version_alias.txt"
DOCX_ERR="$STDOUT_DIR/docx.err.txt"
PPTX_ERR="$STDOUT_DIR/pptx.err.txt"
ZIP_ERR="$STDOUT_DIR/zip.err.txt"
PDF_ERR="$STDOUT_DIR/pdf.err.txt"
JSON_ERR="$STDOUT_DIR/json.err.txt"
JSON_STDOUT="$STDOUT_DIR/txt.json"
JSON_MD="$NO_META_DIR/json_object_basic.md"
JSONL_MD="$NO_META_DIR/jsonl_records_basic.md"
NDJSON_MD="$NO_META_DIR/ndjson_records_basic.md"
XML_MD="$NO_META_DIR/xml_basic.md"
YAML_MD="$NO_META_DIR/yaml_mapping_basic.md"
HTML_MD="$NO_META_DIR/html_simple.md"
MARKDOWN_MD="$NO_META_DIR/markdown_basic_heading_paragraph.md"
MARKDOWN_DOT_MD="$NO_META_DIR/markdown_frontmatter_passthrough.md"
ZIP_MD="$NO_META_DIR/zip_basic_structured.md"
EPUB_MD="$NO_META_DIR/epub_basic_package.md"
DOCX_MD="$NO_META_DIR/docx_image_alt_title_basic.md"
XLSX_MD="$NO_META_DIR/sheet_simple.md"

TXT_MD="$NO_META_DIR/txt_plain.md"
CSV_MD="$NO_META_DIR/csv_basic.md"
TSV_MD="$NO_META_DIR/tsv_basic.md"
TXT_ALIAS_MD="$NO_META_DIR/txt_plain_alias.md"

echo "==> help and version expose current main cli product surface"
run_and_capture "$HELP_STDOUT" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$HELP_STDOUT" 'markitdown-mb [convert|normal] [--format txt|csv|tsv|json|jsonl|ndjson|xml|yaml|yml|html|htm|markdown|md|zip|epub|docx|xlsx|pptx|pdf] [--debug] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--pdf-cleanup none|conservative] [--pdf-tables none|simple] <input> [output]'
assert_contains "$HELP_STDOUT" '--pdf-cleanup none|conservative'
assert_contains "$HELP_STDOUT" '--pdf-tables none|simple'
assert_contains "$HELP_STDOUT" 'Explicit image `--ocr` may invoke local Tesseract; PDF OCR is not supported and scanned/image-only PDFs remain fail-closed.'
assert_contains "$HELP_STDOUT" 'PDF cleanup and simple table reconstruction are explicit opt-in product options'
assert_contains "$HELP_STDOUT" 'Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, yml, html, htm, markdown, md, zip, epub, docx, xlsx, pptx, pdf'
assert_contains "$HELP_STDOUT" 'fail closed'

run_and_capture "$HELP_ALIAS_STDOUT" run_markitdown_cli help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "help alias should succeed"
assert_contains "$HELP_ALIAS_STDOUT" 'markitdown-mb help | --help | -h'

run_and_capture "$HELP_SHORT_STDOUT" run_markitdown_cli -h
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "-h should succeed"
assert_contains "$HELP_SHORT_STDOUT" 'markitdown-mb version | --version'

run_and_capture "$VERSION_STDOUT" run_markitdown_cli --version
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--version should succeed"
assert_contains "$VERSION_STDOUT" 'markitdown-mb 0.3.4'

run_and_capture "$VERSION_ALIAS_STDOUT" run_markitdown_cli version
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "version alias should succeed"
assert_matches_expected "$VERSION_STDOUT" "$VERSION_ALIAS_STDOUT"

echo "==> txt csv tsv json jsonl ndjson xml yaml html markdown zip epub docx xlsx pptx and pdf succeed through main product cli"
run_markitdown_cli normal "$TXT_INPUT" "$TXT_MD"
run_markitdown_cli normal "$CSV_INPUT" "$CSV_MD"
run_markitdown_cli normal "$TSV_INPUT" "$TSV_MD"
run_markitdown_cli normal "$JSON_INPUT" "$JSON_MD"
run_markitdown_cli normal "$JSONL_INPUT" "$JSONL_MD"
run_markitdown_cli normal "$NDJSON_INPUT" "$NDJSON_MD"
run_markitdown_cli normal "$XML_INPUT" "$XML_MD"
run_markitdown_cli normal "$YAML_INPUT" "$YAML_MD"
run_markitdown_cli normal "$HTML_INPUT" "$HTML_MD"
run_markitdown_cli normal "$MARKDOWN_INPUT" "$MARKDOWN_MD"
run_markitdown_cli normal "$MARKDOWN_DOT_INPUT" "$MARKDOWN_DOT_MD"
run_markitdown_cli normal "$ZIP_INPUT" "$ZIP_MD"
run_markitdown_cli normal "$EPUB_INPUT" "$EPUB_MD"
run_markitdown_cli normal "$DOCX_INPUT" "$DOCX_MD"
run_markitdown_cli normal "$XLSX_INPUT" "$XLSX_MD"
run_markitdown_cli normal "$PPTX_INPUT" "$NO_META_DIR/pptx_hidden_slide_basic.md"
run_markitdown_cli normal "$PDF_INPUT" "$NO_META_DIR/root_native_text_baseline.md"
assert_matches_expected "$TXT_EXPECTED" "$TXT_MD"
assert_matches_expected "$CSV_EXPECTED" "$CSV_MD"
assert_matches_expected "$TSV_EXPECTED" "$TSV_MD"
assert_matches_expected "$JSON_EXPECTED" "$JSON_MD"
assert_matches_expected "$JSONL_EXPECTED" "$JSONL_MD"
assert_matches_expected "$NDJSON_EXPECTED" "$NDJSON_MD"
assert_matches_expected "$XML_EXPECTED" "$XML_MD"
assert_matches_expected "$YAML_EXPECTED" "$YAML_MD"
assert_matches_expected "$ROOT/samples/main_process/html/expected/html_simple.md" "$HTML_MD"
assert_matches_expected "$MARKDOWN_EXPECTED" "$MARKDOWN_MD"
assert_matches_expected "$MARKDOWN_DOT_EXPECTED" "$MARKDOWN_DOT_MD"
assert_matches_expected "$ZIP_EXPECTED" "$ZIP_MD"
assert_matches_expected "$ROOT/samples/main_process/epub/expected/epub_basic_package.md" "$EPUB_MD"
assert_matches_expected "$DOCX_EXPECTED" "$DOCX_MD"
assert_matches_expected "$ROOT/samples/main_process/xlsx/expected_next/sheet_simple.md" "$XLSX_MD"
assert_matches_expected "$ROOT/samples/main_process/pptx/expected_next/pptx_hidden_slide_basic.md" "$NO_META_DIR/pptx_hidden_slide_basic.md"
assert_matches_expected "$ROOT/samples/main_process/pdf/expected/root_native_text_baseline.md" "$NO_META_DIR/root_native_text_baseline.md"
assert_file_not_exists "$NO_META_DIR/metadata/txt_plain.metadata.json"

echo "==> bare alias still maps to normal"
run_markitdown_cli "$TXT_INPUT" "$TXT_ALIAS_MD"
assert_matches_expected "$TXT_EXPECTED" "$TXT_ALIAS_MD"

echo "==> debug json remains available on the current main cli"
run_and_capture "$JSON_STDOUT" run_markitdown_cli --debug "$TXT_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--debug txt should succeed"
assert_contains "$JSON_STDOUT" '"renderer_name": "DebugJsonRenderer"'
assert_contains "$JSON_STDOUT" '"source_ref"'

echo "==> pdf OCR remains explicitly unsupported"
run_and_capture "$PDF_ERR" run_markitdown_cli --ocr --ocr-lang eng "$PDF_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "pdf --ocr should fail closed"
assert_contains "$PDF_ERR" 'PDF OCR is not supported'
assert_contains "$PDF_ERR" 'scanned/image-only PDFs'
! grep -Fq 'image OCR provider returned a non-empty OCR model' "$PDF_ERR" || fail "pdf --ocr must not enter the image OCR provider success path"
! grep -Fq 'not configured' "$PDF_ERR" || fail "pdf --ocr must fail before image OCR provider configuration checks"

echo "==> pdf product options are explicit opt-in and default markdown remains stable"
run_markitdown_cli --pdf-cleanup conservative --pdf-tables simple "$PDF_INPUT" "$NO_META_DIR/root_native_text_baseline_optin.md"
assert_matches_expected "$ROOT/samples/main_process/pdf/expected/root_native_text_baseline.md" "$NO_META_DIR/root_native_text_baseline_optin.md"

echo "CLI CONTRACT PASSED"
