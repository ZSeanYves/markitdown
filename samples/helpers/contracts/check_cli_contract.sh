#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp.sh"
source "$ROOT/samples/helpers/shared/cli_runner.sh"
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

TXT_INPUT="$ROOT/samples/main_process/txt/markdown/txt_plain.txt"
TXT_EXPECTED="$ROOT/samples/main_process/txt/expected/markdown/txt_plain.md"
CSV_INPUT="$ROOT/samples/main_process/csv/markdown/csv_basic.csv"
CSV_EXPECTED="$ROOT/samples/main_process/csv/expected/markdown/csv_basic.md"
TSV_INPUT="$ROOT/samples/main_process/tsv/markdown/tsv_basic.tsv"
TSV_EXPECTED="$ROOT/samples/main_process/tsv/expected/markdown/tsv_basic.md"
DOCX_INPUT="$ROOT/samples/main_process/docx/rag/docx_image_alt_title_basic.docx"
DOCX_EXPECTED="$ROOT/samples/main_process/docx/expected/assets/docx_image_alt_title_basic/result.md"
PPTX_INPUT="$ROOT/samples/main_process/pptx/markdown/pptx_hidden_slide_basic.pptx"
XLSX_INPUT="$ROOT/samples/main_process/xlsx/markdown/sheet_simple.xlsx"
ZIP_INPUT="$ROOT/samples/main_process/zip/markdown/zip_basic_structured.zip"
ZIP_EXPECTED="$ROOT/samples/main_process/zip/expected/markdown/zip_basic_structured.md"
EPUB_INPUT="$ROOT/samples/main_process/epub/markdown/epub_basic_package.epub"
PDF_INPUT="$ROOT/samples/main_process/pdf/markdown/root_native_text_baseline.pdf"
MD_INPUT="$ROOT/samples/main_process/markdown/markdown/markdown_heading.md"
MARKDOWN_INPUT="$ROOT/samples/main_process/markdown/markdown/markdown_basic_heading_paragraph.md"
MARKDOWN_DOT_INPUT="$ROOT/samples/main_process/markdown/rag/markdown_frontmatter_passthrough.markdown"
HTML_INPUT="$ROOT/samples/main_process/html/markdown/html_simple.html"
JSON_INPUT="$ROOT/samples/main_process/json/markdown/json_object_basic.json"
JSON_EXPECTED="$ROOT/samples/main_process/json/expected/markdown/json_object_basic.md"
JSONL_INPUT="$ROOT/samples/main_process/jsonl/markdown/jsonl_records_basic.jsonl"
JSONL_EXPECTED="$ROOT/samples/main_process/jsonl/expected/markdown/jsonl_records_basic.md"
NDJSON_INPUT="$ROOT/samples/main_process/ndjson/markdown/ndjson_records_basic.ndjson"
NDJSON_EXPECTED="$ROOT/samples/main_process/ndjson/expected/markdown/ndjson_records_basic.md"
XML_INPUT="$ROOT/samples/main_process/xml/markdown/xml_basic.xml"
XML_EXPECTED="$ROOT/samples/main_process/xml/expected/markdown/xml_basic.md"
YAML_INPUT="$ROOT/samples/main_process/yaml/markdown/yaml_mapping_basic.yaml"
YAML_EXPECTED="$ROOT/samples/main_process/yaml/expected/markdown/yaml_mapping_basic.md"
TOML_INPUT="$ROOT/samples/main_process/toml/markdown/toml_object_basic.toml"
TOML_EXPECTED="$ROOT/samples/main_process/toml/expected/markdown/toml_object_basic.md"
IPYNB_INPUT="$ROOT/samples/main_process/ipynb/markdown/ipynb_markdown_basic.ipynb"
IPYNB_EXPECTED="$ROOT/samples/main_process/ipynb/expected/markdown/ipynb_markdown_basic.md"
OCR_INPUT="$ROOT/samples/main_process/ocr/markdown/ocr_tiny_png.png"
OCR_EXPECTED="$ROOT/samples/main_process/ocr/expected/markdown/ocr_tiny_png.md"
MARKDOWN_EXPECTED="$ROOT/samples/main_process/markdown/expected/markdown/markdown_basic_heading_paragraph.md"
MARKDOWN_DOT_EXPECTED="$ROOT/samples/main_process/markdown/expected/markdown/markdown_frontmatter_passthrough.md"

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
TOML_MD="$NO_META_DIR/toml_object_basic.md"
IPYNB_MD="$NO_META_DIR/ipynb_markdown_basic.md"
HTML_MD="$NO_META_DIR/html_simple.md"
MARKDOWN_MD="$NO_META_DIR/markdown_basic_heading_paragraph.md"
MARKDOWN_DOT_MD="$NO_META_DIR/markdown_frontmatter_passthrough.md"
ZIP_MD="$NO_META_DIR/zip_basic_structured.md"
EPUB_MD="$NO_META_DIR/epub_basic_package.md"
DOCX_MD="$NO_META_DIR/docx_image_alt_title_basic.md"
XLSX_MD="$NO_META_DIR/sheet_simple.md"
OCR_MD="$NO_META_DIR/ocr_tiny_png.md"

TXT_MD="$NO_META_DIR/txt_plain.md"
CSV_MD="$NO_META_DIR/csv_basic.md"
TSV_MD="$NO_META_DIR/tsv_basic.md"
TXT_ALIAS_MD="$NO_META_DIR/txt_plain_alias.md"

echo "==> help and version expose main cli product surface"
run_and_capture "$HELP_STDOUT" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$HELP_STDOUT" 'markitdown-mb [convert|normal] [--format txt|csv|tsv|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|zip|epub|docx|xlsx|pptx|pdf|png|jpg|jpeg|bmp|webp|tif|tiff] [--accurate] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--pdf-cleanup none|conservative] [--pdf-tables none|simple] [--provenance-out <path>] <input> [output]'
assert_contains "$HELP_STDOUT" '--pdf-cleanup none|conservative'
assert_contains "$HELP_STDOUT" '--pdf-tables none|simple'
assert_contains "$HELP_STDOUT" 'Direct image input uses local Tesseract OCR by default; `--no-ocr` disables it. `pdf --accurate` automatically enters the current OCR-only PDF path, while explicit `pdf --ocr` remains supported; both use local `pdftoppm` + Tesseract and require local installation.'
assert_contains "$HELP_STDOUT" 'PDF cleanup and simple table reconstruction are explicit opt-in product options'
assert_contains "$HELP_STDOUT" '`--rag` emits chunked retrieval JSON with the default internal chunking policy.'
assert_contains "$HELP_STDOUT" 'Supported product formats: txt, csv, tsv, json, jsonl, ndjson, ipynb, xml, yaml, yml, toml, html, htm, markdown, md, zip, epub, docx, xlsx, pptx, pdf, png, jpg, jpeg, bmp, webp, tif, tiff'
assert_contains "$HELP_STDOUT" 'fail closed'

run_and_capture "$HELP_ALIAS_STDOUT" run_markitdown_cli help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "help alias should succeed"
assert_contains "$HELP_ALIAS_STDOUT" 'markitdown-mb help | --help | -h'

run_and_capture "$HELP_SHORT_STDOUT" run_markitdown_cli -h
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "-h should succeed"
assert_contains "$HELP_SHORT_STDOUT" 'markitdown-mb version | --version'

run_and_capture "$VERSION_STDOUT" run_markitdown_cli --version
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--version should succeed"
assert_contains "$VERSION_STDOUT" 'markitdown-mb 0.4.2'

run_and_capture "$VERSION_ALIAS_STDOUT" run_markitdown_cli version
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "version alias should succeed"
assert_matches_expected "$VERSION_STDOUT" "$VERSION_ALIAS_STDOUT"

echo "==> txt csv tsv json jsonl ndjson ipynb xml yaml toml html markdown zip epub docx xlsx pptx pdf and ocr succeed through main product cli"
run_markitdown_cli normal "$TXT_INPUT" "$TXT_MD"
run_markitdown_cli normal "$CSV_INPUT" "$CSV_MD"
run_markitdown_cli normal "$TSV_INPUT" "$TSV_MD"
run_markitdown_cli normal "$JSON_INPUT" "$JSON_MD"
run_markitdown_cli normal "$JSONL_INPUT" "$JSONL_MD"
run_markitdown_cli normal "$NDJSON_INPUT" "$NDJSON_MD"
run_markitdown_cli normal "$IPYNB_INPUT" "$IPYNB_MD"
run_markitdown_cli normal "$XML_INPUT" "$XML_MD"
run_markitdown_cli normal "$YAML_INPUT" "$YAML_MD"
run_markitdown_cli normal "$TOML_INPUT" "$TOML_MD"
run_markitdown_cli normal "$HTML_INPUT" "$HTML_MD"
run_markitdown_cli normal "$MARKDOWN_INPUT" "$MARKDOWN_MD"
run_markitdown_cli normal "$MARKDOWN_DOT_INPUT" "$MARKDOWN_DOT_MD"
run_markitdown_cli normal "$ZIP_INPUT" "$ZIP_MD"
run_markitdown_cli normal "$EPUB_INPUT" "$EPUB_MD"
run_markitdown_cli normal "$DOCX_INPUT" "$DOCX_MD"
run_markitdown_cli normal "$XLSX_INPUT" "$XLSX_MD"
run_markitdown_cli normal "$PPTX_INPUT" "$NO_META_DIR/pptx_hidden_slide_basic.md"
run_markitdown_cli normal "$PDF_INPUT" "$NO_META_DIR/root_native_text_baseline.md"
run_markitdown_cli normal "$OCR_INPUT" "$OCR_MD"
assert_matches_expected "$TXT_EXPECTED" "$TXT_MD"
assert_matches_expected "$CSV_EXPECTED" "$CSV_MD"
assert_matches_expected "$TSV_EXPECTED" "$TSV_MD"
assert_matches_expected "$JSON_EXPECTED" "$JSON_MD"
assert_matches_expected "$JSONL_EXPECTED" "$JSONL_MD"
assert_matches_expected "$NDJSON_EXPECTED" "$NDJSON_MD"
assert_matches_expected "$IPYNB_EXPECTED" "$IPYNB_MD"
assert_matches_expected "$XML_EXPECTED" "$XML_MD"
assert_matches_expected "$YAML_EXPECTED" "$YAML_MD"
assert_matches_expected "$TOML_EXPECTED" "$TOML_MD"
assert_matches_expected "$ROOT/samples/main_process/html/expected/markdown/html_simple.md" "$HTML_MD"
assert_matches_expected "$MARKDOWN_EXPECTED" "$MARKDOWN_MD"
assert_matches_expected "$MARKDOWN_DOT_EXPECTED" "$MARKDOWN_DOT_MD"
assert_matches_expected "$ZIP_EXPECTED" "$ZIP_MD"
assert_matches_expected "$ROOT/samples/main_process/epub/expected/markdown/epub_basic_package.md" "$EPUB_MD"
assert_matches_expected "$DOCX_EXPECTED" "$DOCX_MD"
assert_matches_expected "$ROOT/samples/main_process/xlsx/expected/markdown/sheet_simple.md" "$XLSX_MD"
assert_matches_expected "$ROOT/samples/main_process/pptx/expected/markdown/pptx_hidden_slide_basic.md" "$NO_META_DIR/pptx_hidden_slide_basic.md"
assert_matches_expected "$ROOT/samples/main_process/pdf/expected/markdown/root_native_text_baseline.md" "$NO_META_DIR/root_native_text_baseline.md"
assert_matches_expected "$OCR_EXPECTED" "$OCR_MD"
assert_file_not_exists "$NO_META_DIR/metadata/txt_plain.metadata.json"

echo "==> bare alias still maps to normal"
run_markitdown_cli "$TXT_INPUT" "$TXT_ALIAS_MD"
assert_matches_expected "$TXT_EXPECTED" "$TXT_ALIAS_MD"

echo "==> debug json remains available on the main cli"
run_and_capture "$JSON_STDOUT" run_markitdown_cli --debug "$TXT_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--debug txt should succeed"
assert_contains "$JSON_STDOUT" '"renderer_name": "DebugJsonRenderer"'
assert_contains "$JSON_STDOUT" '"source_ref"'

echo "==> rag json remains available on the main cli"
run_and_capture "$DOCX_ERR" run_markitdown_cli --rag "$DOCX_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--rag docx should succeed"
assert_contains "$DOCX_ERR" '"output_format": "rag_json"'
assert_contains "$DOCX_ERR" '"chunks"'

echo "==> pdf OCR is a dependency-backed product path"
run_and_capture "$PDF_ERR" run_markitdown_cli --ocr --ocr-lang eng "$PDF_INPUT"
if [[ "$CAPTURED_STATUS" -eq 0 ]]; then
  assert_contains "$PDF_ERR" 'PDF'
else
  assert_contains "$PDF_ERR" 'pdftoppm'
fi

echo "==> pdf product options are explicit opt-in and default markdown remains stable"
run_markitdown_cli --pdf-cleanup conservative --pdf-tables simple "$PDF_INPUT" "$NO_META_DIR/root_native_text_baseline_optin.md"
assert_matches_expected "$ROOT/samples/main_process/pdf/expected/markdown/root_native_text_baseline.md" "$NO_META_DIR/root_native_text_baseline_optin.md"

echo "CLI CONTRACT PASSED"
