#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "debug_contract")"

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
  grep -q "$needle" "$path" || fail "expected $path to contain: $needle"
}

run_debug_json() {
  local input="$1"
  local out="$2"
  run_markitdown_cli debug --json "$input" > "$out"
}

TXT_INPUT="$ROOT/samples/main_process/txt/txt_plain.txt"
HTML_INPUT="$ROOT/samples/main_process/html/html_entities.html"
XLSX_INPUT="$ROOT/samples/main_process/xlsx/sheet_simple.xlsx"
DOCX_INPUT="$ROOT/samples/main_process/docx/docx_image_alt_title.docx"
PPTX_INPUT="$ROOT/samples/main_process/pptx/pptx_hidden_slide_basic.pptx"
PDF_INPUT="$ROOT/samples/main_process/pdf/text_simple.pdf"
ZIP_INPUT="$ROOT/samples/main_process/zip/zip_basic_structured.zip"
EPUB_INPUT="$ROOT/samples/main_process/epub/epub_basic_package.epub"

echo "==> debug inspect json txt/html/xlsx/docx/pptx/pdf/zip/epub"
run_debug_json "$TXT_INPUT" "$OUT_DIR/txt.json"
run_debug_json "$HTML_INPUT" "$OUT_DIR/html.json"
run_debug_json "$XLSX_INPUT" "$OUT_DIR/xlsx.json"
run_debug_json "$DOCX_INPUT" "$OUT_DIR/docx.json"
run_debug_json "$PPTX_INPUT" "$OUT_DIR/pptx.json"
run_debug_json "$PDF_INPUT" "$OUT_DIR/pdf.json"
run_debug_json "$ZIP_INPUT" "$OUT_DIR/zip.json"
run_debug_json "$EPUB_INPUT" "$OUT_DIR/epub.json"

assert_contains "$OUT_DIR/txt.json" '"detected_format": "txt"'
assert_contains "$OUT_DIR/html.json" '"detected_format": "html"'
assert_contains "$OUT_DIR/xlsx.json" '"detected_format": "xlsx"'
assert_contains "$OUT_DIR/docx.json" '"detected_format": "docx"'
assert_contains "$OUT_DIR/pptx.json" '"detected_format": "pptx"'
assert_contains "$OUT_DIR/pdf.json" '"detected_format": "pdf"'
assert_contains "$OUT_DIR/zip.json" '"detected_format": "zip"'
assert_contains "$OUT_DIR/epub.json" '"detected_format": "epub"'

echo "==> pdf normalization section present"
assert_contains "$OUT_DIR/pdf.json" '"name": "normalization"'
assert_contains "$OUT_DIR/pdf.json" '"output_profile": "PdfText"'
assert_contains "$OUT_DIR/pdf.json" '"name": "pdf_backend"'
assert_contains "$OUT_DIR/pdf.json" '"name": "pdf_pages"'
assert_contains "$OUT_DIR/pdf.json" '"name": "pdf_text_model"'
assert_contains "$OUT_DIR/pdf.json" '"name": "pdf_annotations"'
assert_contains "$OUT_DIR/pdf.json" '"name": "pdf_links"'
assert_contains "$OUT_DIR/pdf.json" '"name": "pdf_pipeline"'

echo "==> non-pdf debug no longer errors"
assert_contains "$OUT_DIR/docx.json" '"sections"'
assert_contains "$OUT_DIR/xlsx.json" '"format_specific"'

echo "==> legacy pdf debug remains compatible"
run_markitdown_cli debug pipeline "$PDF_INPUT" "$OUT_DIR/pdf_legacy.md" > "$OUT_DIR/pdf_legacy.txt"
[[ -f "$OUT_DIR/pdf_legacy.md" ]] || fail "expected legacy pdf debug markdown output"
assert_contains "$OUT_DIR/pdf_legacy.txt" 'legacy PDF debug mode is deprecated'
assert_contains "$OUT_DIR/pdf_legacy.txt" 'scope "pipeline" now maps to unified debug inspect output'

echo "DEBUG CONTRACT PASSED"
