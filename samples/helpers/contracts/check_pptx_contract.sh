#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "pptx_contract")"

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

PPTX_INPUT="$ROOT/samples/main_process/pptx/pptx_hidden_slide_basic.pptx"
PPTX_SLIDE_ORDER_INPUT="$ROOT/samples/main_process/pptx/pptx_slide_order.pptx"
PPTX_NOTES_INPUT="$ROOT/samples/main_process/pptx/pptx_speaker_notes_basic.pptx"
PPTX_IMAGE_INPUT="$ROOT/samples/main_process/pptx/assets/pptx_image_single.pptx"
PPTX_HELP="$OUT_DIR/help.txt"
PPTX_ERR="$OUT_DIR/pptx.err.txt"
PPTX_ORDER_OUT="$OUT_DIR/pptx_slide_order.md"
PPTX_IMAGE_OUT="$OUT_DIR/pptx_image_single.md"
PPTX_IMAGE_JSON="$OUT_DIR/pptx_image_single.json"
PPTX_HIDDEN_JSON="$OUT_DIR/pptx_hidden_slide_basic.json"
PPTX_NOTES_OUT="$OUT_DIR/pptx_speaker_notes_basic.md"
SAMPLES_ERR="$OUT_DIR/samples_check_pptx.err.txt"
PDF_ERR="$OUT_DIR/pdf.err.txt"
OCR_ERR="$OUT_DIR/ocr.err.txt"
FORMATS_PKG="$ROOT/formats/moon.pkg"
REGISTRY_IMPL="$ROOT/formats/registry.mbt"
REGISTRY_IMPL="$ROOT/formats/registry.mbt"
SHARED_PKG="$ROOT/format_readers/ooxml/shared/moon.pkg"
SHARED_IMPL="$ROOT/format_readers/ooxml/shared/shared.mbt"
PPTX_RUNTIME_PKG="$ROOT/formats/pptx/moon.pkg"
PPTX_RUNTIME_IMPL="$ROOT/formats/pptx/parser.mbt"
PPTX_CONTRACT_IMPL="$ROOT/formats/format_contracts.mbt"
PPTX_DOC_PKG="$ROOT/format_readers/ooxml/pptx/moon.pkg"

echo "==> pptx runtime stays root-pipeline native and legacy-free"
assert_contains "$PPTX_DOC_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/package'
assert_not_contains "$PPTX_DOC_PKG" 'ZSeanYves/markitdown/convert/pptx'
assert_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/formats/pptx'
assert_contains "$PPTX_RUNTIME_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/pptx'
assert_contains "$PPTX_RUNTIME_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/package'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/convert/pptx'
assert_not_contains "$SHARED_PKG" 'ZSeanYves/markitdown/format_readers/ooxml/pptx'
assert_not_contains "$SHARED_PKG" 'ZSeanYves/markitdown/convert/pptx'
assert_contains "$REGISTRY_IMPL" '@input.DetectedFormat::Pptx'
assert_contains "$REGISTRY_IMPL" 'pptx_parser()'
assert_not_contains "$REGISTRY_IMPL" 'pptx_parser_contract()'
assert_not_contains "$SHARED_IMPL" 'ZSeanYves/markitdown/format_readers/ooxml/pptx'
assert_not_contains "$SHARED_IMPL" '@legacy'
assert_not_contains "$PPTX_CONTRACT_IMPL" 'doc_parse/pptx'
assert_not_contains "$PPTX_CONTRACT_IMPL" 'convert/pptx'
assert_not_contains "$PPTX_CONTRACT_IMPL" '@legacy'
assert_not_contains "$PPTX_CONTRACT_IMPL" 'emitter_markdown'
assert_not_contains "$PPTX_CONTRACT_IMPL" 'dispatcher'
assert_not_contains "$PPTX_RUNTIME_IMPL" 'convert/pptx'
assert_not_contains "$PPTX_RUNTIME_IMPL" '@legacy'
assert_not_contains "$PPTX_RUNTIME_IMPL" 'emitter_markdown'
assert_not_contains "$PPTX_RUNTIME_IMPL" 'dispatcher'

echo "==> help exposes pptx on the main product cli"
run_and_capture "$PPTX_HELP" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$PPTX_HELP" 'Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, yml, html, htm, markdown, md, zip, epub, docx, xlsx, pptx, pdf'
assert_contains "$PPTX_HELP" 'pptx'

echo "==> main cli and repo-local sample gate both restore pptx"
run_and_capture "$PPTX_ERR" run_markitdown_cli normal "$PPTX_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "pptx should succeed"
assert_contains "$PPTX_ERR" '## Slide 1'
assert_not_contains "$PPTX_ERR" '(hidden)'
assert_not_contains "$PPTX_ERR" 'pptx_raw_fallback'
assert_not_contains "$PPTX_ERR" 'pptx_legacy_fallback'

run_and_capture "$SAMPLES_ERR" bash "$ROOT/samples/check.sh" --format pptx
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "samples/check.sh --format pptx should succeed"
assert_contains "$SAMPLES_ERR" 'result: pass'

echo "==> expected-next baselines lock slide order and speaker notes structure"
run_markitdown_cli normal "$PPTX_SLIDE_ORDER_INPUT" "$PPTX_ORDER_OUT"
assert_file_exists "$PPTX_ORDER_OUT"
assert_matches_expected \
  "$ROOT/samples/main_process/pptx/expected_next/pptx_slide_order.md" \
  "$PPTX_ORDER_OUT"
run_markitdown_cli normal "$PPTX_NOTES_INPUT" "$PPTX_NOTES_OUT"
assert_file_exists "$PPTX_NOTES_OUT"
assert_matches_expected \
  "$ROOT/samples/main_process/pptx/expected_next/pptx_speaker_notes_basic.md" \
  "$PPTX_NOTES_OUT"
assert_contains "$PPTX_NOTES_OUT" '### Speaker Notes'
assert_not_contains "$PPTX_NOTES_OUT" 'Speaker Notes 1'

echo "==> debug json keeps PresentationModel diagnostics and hidden-slide policy visible"
run_and_capture "$PPTX_HIDDEN_JSON" run_markitdown_cli --json "$ROOT/samples/main_process/pptx/pptx_hidden_slides_policy.pptx"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "pptx hidden-slide debug json should succeed"
assert_contains "$PPTX_HIDDEN_JSON" '"detected_format": "pptx"'
assert_contains "$PPTX_HIDDEN_JSON" '"parser_mode": "presentation_model"'
assert_contains "$PPTX_HIDDEN_JSON" '"effective_mode": "presentation_model"'
assert_contains "$PPTX_HIDDEN_JSON" '"ir_input_kind": "document"'
assert_contains "$PPTX_HIDDEN_JSON" '"event_granularity": "pptx_slide"'
assert_contains "$PPTX_HIDDEN_JSON" '"office_document_kind": "pptx"'
assert_contains "$PPTX_HIDDEN_JSON" '"runtime_exposed": "true"'
assert_contains "$PPTX_HIDDEN_JSON" '"pptx_hidden_slide_count": "1"'
assert_contains "$PPTX_HIDDEN_JSON" '"pptx_reading_order_strategy": "placeholder_then_geometry"'
assert_contains "$PPTX_HIDDEN_JSON" 'hidden pptx slide skipped: Slide 2'
assert_contains "$PPTX_HIDDEN_JSON" '"slide_part": "ppt/slides/slide1.xml"'
assert_contains "$PPTX_HIDDEN_JSON" '"placeholder_type": "center_title"'
assert_not_contains "$PPTX_HIDDEN_JSON" 'pptx_raw_fallback'
assert_not_contains "$PPTX_HIDDEN_JSON" 'pptx_legacy_fallback'
assert_not_contains "$PPTX_HIDDEN_JSON" 'legacy_dispatcher_used'
assert_not_contains "$PPTX_HIDDEN_JSON" 'convert_pptx_used'
assert_not_contains "$PPTX_HIDDEN_JSON" 'xml_order_text_dump'

echo "==> package-local image assets stay output-boundary only and external media stay no-fetch"
run_markitdown_cli normal "$PPTX_IMAGE_INPUT" "$PPTX_IMAGE_OUT"
assert_file_exists "$PPTX_IMAGE_OUT"
assert_matches_expected \
  "$ROOT/samples/main_process/pptx/expected_next/assets/pptx_image_single.md" \
  "$PPTX_IMAGE_OUT"
assert_file_exists "$OUT_DIR/assets/image01.png"
run_and_capture "$PPTX_IMAGE_JSON" run_markitdown_cli --json "$PPTX_IMAGE_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "pptx image debug json should succeed"
assert_contains "$PPTX_IMAGE_JSON" '"asset_count": "1"'
assert_contains "$PPTX_IMAGE_JSON" '"media_asset_count": "1"'
assert_contains "$PPTX_IMAGE_JSON" '"materialized_asset_count": "1"'
assert_contains "$PPTX_IMAGE_JSON" '"pptx_image_count": "1"'
assert_contains "$PPTX_IMAGE_JSON" '"pptx_external_media_count": "0"'
assert_contains "$PPTX_IMAGE_JSON" '"path": "assets/image01.png"'
assert_contains "$PPTX_IMAGE_JSON" '"source_path": "ppt/media/image1.png"'
assert_contains "$PPTX_IMAGE_JSON" '"zip_container_format": "pptx"'

echo "==> pdf is restored while ocr/image surfaces remain constrained"
run_markitdown_cli normal "$ROOT/samples/main_process/pdf/root_native_text_baseline.pdf" "$OUT_DIR/pdf_text_simple.md"
assert_matches_expected "$ROOT/samples/main_process/pdf/expected/root_native_text_baseline.md" "$OUT_DIR/pdf_text_simple.md"
run_and_capture "$PDF_ERR" run_markitdown_cli --ocr --ocr-lang eng "$ROOT/samples/main_process/pdf/root_native_text_baseline.pdf"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "pdf --ocr should fail closed"
assert_contains "$PDF_ERR" 'PDF OCR is not supported'
assert_contains "$PDF_ERR" 'scanned/image-only PDFs'
run_and_capture "$OCR_ERR" run_markitdown_cli normal "$ROOT/samples/fixtures/ocr/tiny_ocr_sample.png"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "ocr/image should fail closed"
assert_contains "$OCR_ERR" 'unsupported format'
assert_contains "$OCR_ERR" 'png'
assert_contains "$OCR_ERR" 'current main CLI'

echo "PPTX CONTRACT PASSED"
