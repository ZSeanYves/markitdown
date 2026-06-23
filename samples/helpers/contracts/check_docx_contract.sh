#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "docx_contract")"

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

DOCX_INPUT="$ROOT/samples/main_process/docx/metadata/docx_image_alt_title_basic.docx"
DOCX_EXPECTED="$ROOT/samples/main_process/docx/expected/metadata/docx_image_alt_title_basic.md"
DOCX_OUT="$OUT_DIR/docx_image_alt_title_basic.md"
DOCX_JSON="$OUT_DIR/docx_image_alt_title_basic.json"
DOCX_HELP="$OUT_DIR/help.txt"
DOCX_ERR="$OUT_DIR/docx.err.txt"
PPTX_ERR="$OUT_DIR/pptx.err.txt"
PDF_ERR="$OUT_DIR/pdf.err.txt"
REGISTRY_IMPL="$ROOT/formats/registry.mbt"
DOCX_RUNTIME_PKG="$ROOT/formats/docx/moon.pkg"
DOCX_RUNTIME_IMPL="$ROOT/formats/docx/parser.mbt"
FORMATS_PKG="$ROOT/formats/moon.pkg"
CLI_PKG="$ROOT/cli/moon.pkg"
SHARED_PKG="$ROOT/format_readers/ooxml/shared/moon.pkg"
DOC_PARSE_DOCX_PKG="$ROOT/format_readers/ooxml/docx/moon.pkg"
DOC_PARSE_OOXML_PKG="$ROOT/format_readers/ooxml/package/moon.pkg"

echo "==> main cli docx contract stays on the promoted root pipeline foundation"
assert_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/formats/docx'
assert_contains "$DOC_PARSE_DOCX_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/package'
assert_contains "$DOCX_RUNTIME_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/docx'
assert_contains "$DOCX_RUNTIME_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/package'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/convert/docx'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/convert/docx_v2'
assert_not_contains "$CLI_PKG" 'ZSeanYves/markitdown/convert/docx'
assert_not_contains "$SHARED_PKG" 'ZSeanYves/markitdown/convert/'
assert_contains "$REGISTRY_IMPL" '@input.DetectedFormat::Docx'
assert_contains "$REGISTRY_IMPL" 'docx_parser()'
assert_not_contains "$DOCX_RUNTIME_IMPL" 'convert/docx'
assert_not_contains "$DOCX_RUNTIME_IMPL" 'convert/docx_v2'
assert_not_contains "$DOCX_RUNTIME_IMPL" '@legacy'
assert_not_contains "$DOCX_RUNTIME_IMPL" 'emitter_markdown'
assert_not_contains "$DOCX_RUNTIME_IMPL" 'dispatcher'

echo "==> help keeps docx exposed and unsupported formats fail closed"
run_and_capture "$DOCX_HELP" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$DOCX_HELP" "Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, yml, html, htm, markdown, md, zip, epub, docx, xlsx, pptx, pdf"

echo "==> main cli docx markdown output stays renderer-owned and root-pipeline native"
run_markitdown_cli normal "$DOCX_INPUT" "$DOCX_OUT"
assert_file_exists "$DOCX_OUT"
assert_matches_expected "$DOCX_EXPECTED" "$DOCX_OUT"
assert_not_contains "$DOCX_OUT" "docx_raw_fallback"
assert_not_contains "$DOCX_OUT" "docx_legacy_fallback"

echo "==> docx debug json exposes document-model diagnostics and office source refs"
run_and_capture "$DOCX_JSON" run_markitdown_cli --json "$DOCX_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "docx debug json should succeed"
assert_contains "$DOCX_JSON" '"detected_format": "docx"'
assert_contains "$DOCX_JSON" '"effective_mode": "document_model"'
assert_contains "$DOCX_JSON" '"ir_input_kind": "document"'
assert_contains "$DOCX_JSON" '"event_granularity": "docx_block"'
assert_contains "$DOCX_JSON" '"office_document_kind": "docx"'
assert_contains "$DOCX_JSON" '"runtime_exposed": "true"'
assert_contains "$DOCX_JSON" '"relationship_id"'
assert_contains "$DOCX_JSON" '"part_name"'
assert_contains "$DOCX_JSON" '"paragraph_index"'
assert_contains "$DOCX_JSON" '"pass_trace"'
assert_not_contains "$DOCX_JSON" 'docx_raw_fallback'
assert_not_contains "$DOCX_JSON" 'docx_legacy_fallback'
assert_not_contains "$DOCX_JSON" 'legacy_dispatcher_used'
assert_not_contains "$DOCX_JSON" 'convert_docx_used'
assert_not_contains "$DOCX_JSON" 'convert_docx_v2_used'

echo "==> pptx and pdf are both restored on the main product cli"
run_markitdown_cli normal "$ROOT/samples/main_process/pptx/pptx_hidden_slide_basic.pptx" "$OUT_DIR/pptx_hidden_slide_basic.md"
assert_matches_expected "$ROOT/samples/main_process/pptx/expected_next/pptx_hidden_slide_basic.md" "$OUT_DIR/pptx_hidden_slide_basic.md"

run_markitdown_cli normal "$ROOT/samples/main_process/pdf/root_native_text_baseline.pdf" "$OUT_DIR/pdf_text_simple.md"
assert_matches_expected "$ROOT/samples/main_process/pdf/expected/root_native_text_baseline.md" "$OUT_DIR/pdf_text_simple.md"

echo "DOCX CONTRACT PASSED"
