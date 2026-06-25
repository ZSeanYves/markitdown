#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "xlsx_contract")"

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

assert_not_contains() {
  local path="$1"
  local needle="$2"
  if grep -Fq -- "$needle" "$path"; then
    fail "did not expect $path to contain: $needle"
  fi
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

XLSX_INPUT="$ROOT/samples/main_process/xlsx/sheet_simple.xlsx"
XLSX_EXPECTED="$ROOT/samples/main_process/xlsx/expected_next/sheet_simple.md"
XLSX_OUT="$OUT_DIR/sheet_simple.md"
XLSX_JSON="$OUT_DIR/sheet_simple.json"
XLSX_HIDDEN_JSON="$OUT_DIR/xlsx_hidden_sheets_policy.json"
XLSX_FORMULA_OUT="$OUT_DIR/xlsx_formula_missing_cache.md"
XLSX_HELP="$OUT_DIR/help.txt"
PPTX_ERR="$OUT_DIR/pptx.err.txt"
PDF_ERR="$OUT_DIR/pdf.err.txt"
FORMATS_PKG="$ROOT/formats/moon.pkg"
CLI_PKG="$ROOT/cli/moon.pkg"
SHARED_PKG="$ROOT/format_readers/ooxml/shared/moon.pkg"
REGISTRY_IMPL="$ROOT/formats/registry.mbt"
XLSX_RUNTIME_PKG="$ROOT/formats/xlsx/moon.pkg"
XLSX_RUNTIME_IMPL="$ROOT/formats/xlsx/parser.mbt"

echo "==> main cli xlsx contract stays on the promoted root pipeline foundation"
assert_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/formats/xlsx'
assert_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/shared'
assert_contains "$XLSX_RUNTIME_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/package'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/doc_parse/xlsx'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/convert/xlsx'
assert_not_contains "$CLI_PKG" 'ZSeanYves/markitdown/convert/xlsx'
assert_not_contains "$SHARED_PKG" 'ZSeanYves/markitdown/doc_parse/xlsx'
assert_not_contains "$SHARED_PKG" 'ZSeanYves/markitdown/convert/xlsx'
assert_contains "$REGISTRY_IMPL" '@input.DetectedFormat::Xlsx'
assert_contains "$REGISTRY_IMPL" 'xlsx_parser()'
assert_not_contains "$XLSX_RUNTIME_IMPL" 'doc_parse/xlsx'
assert_not_contains "$XLSX_RUNTIME_IMPL" 'convert/xlsx'
assert_not_contains "$XLSX_RUNTIME_IMPL" '@legacy'
assert_not_contains "$XLSX_RUNTIME_IMPL" 'emitter_markdown'
assert_not_contains "$XLSX_RUNTIME_IMPL" 'dispatcher'

echo "==> help keeps xlsx exposed and unsupported formats fail closed"
run_and_capture "$XLSX_HELP" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$XLSX_HELP" 'Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, yml, html, htm, markdown, md, zip, epub, docx, xlsx, pptx, pdf'

echo "==> main cli xlsx markdown output stays renderer-owned and expected-next locked"
run_markitdown_cli normal "$XLSX_INPUT" "$XLSX_OUT"
assert_file_exists "$XLSX_OUT"
assert_matches_expected "$XLSX_EXPECTED" "$XLSX_OUT"
assert_not_contains "$XLSX_OUT" 'xlsx_raw_fallback'
assert_not_contains "$XLSX_OUT" 'xlsx_legacy_fallback'

echo "==> xlsx debug json exposes workbook-model diagnostics and workbook part metadata"
run_and_capture "$XLSX_JSON" run_markitdown_cli --debug "$XLSX_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "xlsx debug json should succeed"
assert_contains "$XLSX_JSON" '"detected_format": "xlsx"'
assert_contains "$XLSX_JSON" '"effective_mode": "workbook_model"'
assert_contains "$XLSX_JSON" '"ir_input_kind": "document"'
assert_contains "$XLSX_JSON" '"event_granularity": "xlsx_sheet"'
assert_contains "$XLSX_JSON" '"office_document_kind": "xlsx"'
assert_contains "$XLSX_JSON" '"xlsx_workbook_part": "xl/workbook.xml"'
assert_contains "$XLSX_JSON" '"part_name"'
assert_contains "$XLSX_JSON" '"relationship_id"'
assert_not_contains "$XLSX_JSON" 'doc_parse_xlsx_used'
assert_not_contains "$XLSX_JSON" 'convert_xlsx_used'
assert_not_contains "$XLSX_JSON" 'legacy_dispatcher_used'
assert_not_contains "$XLSX_JSON" 'formula_evaluation_enabled'

echo "==> hidden sheet policy stays diagnostics-first and formulas stay preserved without execution"
run_and_capture \
  "$XLSX_HIDDEN_JSON" \
  run_markitdown_cli --debug "$ROOT/samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "xlsx hidden-sheet debug json should succeed"
assert_contains "$XLSX_HIDDEN_JSON" '"xlsx_hidden_sheet_count": "1"'
assert_contains "$XLSX_HIDDEN_JSON" '"xlsx_very_hidden_sheet_count": "1"'
assert_contains "$XLSX_HIDDEN_JSON" 'hidden xlsx sheet skipped: HiddenData'
assert_contains "$XLSX_HIDDEN_JSON" 'very hidden xlsx sheet skipped: VeryHiddenAudit'
run_markitdown_cli normal \
  "$ROOT/samples/main_process/xlsx/xlsx_formula_missing_cache.xlsx" \
  "$XLSX_FORMULA_OUT"
assert_matches_expected \
  "$ROOT/samples/main_process/xlsx/expected_next/xlsx_formula_missing_cache.md" \
  "$XLSX_FORMULA_OUT"
assert_not_contains "$XLSX_FORMULA_OUT" '| Missing numeric cache | 3 |'
assert_contains "$XLSX_FORMULA_OUT" '| Missing numeric cache | =1+2 |'

echo "==> pptx and pdf are restored on the main product cli"
run_markitdown_cli normal "$ROOT/samples/main_process/pptx/pptx_hidden_slide_basic.pptx" "$OUT_DIR/pptx_hidden_slide_basic.md"
assert_matches_expected "$ROOT/samples/main_process/pptx/expected_next/pptx_hidden_slide_basic.md" "$OUT_DIR/pptx_hidden_slide_basic.md"

run_markitdown_cli normal "$ROOT/samples/main_process/pdf/root_native_text_baseline.pdf" "$OUT_DIR/pdf_text_simple.md"
assert_matches_expected "$ROOT/samples/main_process/pdf/expected/root_native_text_baseline.md" "$OUT_DIR/pdf_text_simple.md"

echo "XLSX CONTRACT PASSED"
