#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp.sh"
source "$ROOT/samples/helpers/shared/cli_runner.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "pdf_signal_contract")"

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
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  if grep -Fq -- "$needle" "$path"; then
    fail "expected $path to not contain: $needle"
  fi
}

assert_matches_expected() {
  local expected="$1"
  local actual="$2"
  diff -u "$expected" "$actual" >/dev/null || fail "output mismatch: $actual"
}

assert_fixed_count() {
  local expected_count="$1"
  local needle="$2"
  local path="$3"
  local actual_count
  actual_count="$(grep -Fc -- "$needle" "$path")"
  [[ "$actual_count" == "$expected_count" ]] || fail "expected $needle to appear $expected_count times in $path, got $actual_count"
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

ROOT_BASELINE_INPUT="$ROOT/samples/main_process/pdf/markdown/root_native_text_baseline.pdf"
ROOT_BASELINE_EXPECTED="$ROOT/samples/main_process/pdf/expected/markdown/root_native_text_baseline.md"
LINK_INPUT="$ROOT/samples/main_process/pdf/rag/pdf_metadata_uri_link.pdf"
HEADER_FOOTER_INPUT="$ROOT/samples/main_process/pdf/markdown/pdf_header_footer_variants_phase15.pdf"
TABLE_INPUT="$ROOT/samples/main_process/pdf/markdown/pdf_simple_table_like.pdf"
SCAN_INPUT="$OUT_DIR/root_empty_text_layer.pdf"

ROOT_BASELINE_MD="$OUT_DIR/root_native_text_baseline.md"
ROOT_BASELINE_JSON="$OUT_DIR/root_native_text_baseline.json"
LINK_MD="$OUT_DIR/pdf_metadata_uri_link.md"
LINK_JSON="$OUT_DIR/pdf_metadata_uri_link.json"
HEADER_FOOTER_MD="$OUT_DIR/pdf_header_footer_variants_phase15.md"
HEADER_FOOTER_JSON="$OUT_DIR/pdf_header_footer_variants_phase15.json"
TABLE_MD="$OUT_DIR/pdf_simple_table_like.md"
TABLE_JSON="$OUT_DIR/pdf_simple_table_like.json"
SCAN_ERR="$OUT_DIR/root_empty_text_layer.err.txt"
PDF_OCR_ERR="$OUT_DIR/pdf_ocr.err.txt"

echo "==> pdf signal native baseline markdown remains unchanged"
run_markitdown_cli normal "$ROOT_BASELINE_INPUT" "$ROOT_BASELINE_MD"
assert_matches_expected "$ROOT_BASELINE_EXPECTED" "$ROOT_BASELINE_MD"

echo "==> pdf signal native baseline debug json exposes current metadata-only signal metrics"
run_markitdown_cli --debug "$ROOT_BASELINE_INPUT" >"$ROOT_BASELINE_JSON"
assert_contains "$ROOT_BASELINE_JSON" '"detected_format": "pdf"'
assert_contains "$ROOT_BASELINE_JSON" '"product_path_enabled": "true"'
assert_contains "$ROOT_BASELINE_JSON" '"renderer_name": "DebugJsonRenderer"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_native_backend": "true"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_native_text_baseline": "true"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_ocr_used": "false"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_v2_used": "false"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_empty_text_layer": "false"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_page_count": "1"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_text_block_count": "1"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_text_line_count": "1"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_text_span_count": "1"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_grouping_strategy": "conservative_v1"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_grouping_paragraph_count": "1"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_grouping_line_merge_count": "0"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_header_footer_candidate_strategy": "conservative_v1"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_header_candidate_count": "0"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_footer_candidate_count": "0"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_header_footer_candidate_count": "0"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_header_footer_filter_policy": "disabled"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_header_footer_filter_enabled": "false"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_header_footer_removed_count": "0"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_cleanup_mode": "none"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_cleanup_enabled": "false"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_cleanup_default_mode": "none"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_cleanup_opt_in_mode": "conservative"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_candidate_strategy": "conservative_v1"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_candidate_count": "0"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_row_candidate_count": "0"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_reconstruction_policy": "disabled"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_reconstruction_enabled": "false"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_reconstruction_table_count": "0"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_mode": "none"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_enabled": "false"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_default_mode": "none"'
assert_contains "$ROOT_BASELINE_JSON" '"pdf_table_opt_in_mode": "simple"'
assert_not_contains "$ROOT_BASELINE_JSON" '"pdf_v2"'
assert_not_contains "$ROOT_BASELINE_JSON" '"pdf_debug"'
assert_not_contains "$ROOT_BASELINE_JSON" 'DocLayNet'
assert_not_contains "$ROOT_BASELINE_JSON" 'layout_model'
assert_not_contains "$ROOT_BASELINE_JSON" 'quality-lab'
assert_not_contains "$ROOT_BASELINE_JSON" 'tesseract'
assert_not_contains "$ROOT_BASELINE_JSON" 'ocrmypdf'
assert_not_contains "$ROOT_BASELINE_JSON" '"pdf_raster_backend"'
assert_not_contains "$ROOT_BASELINE_JSON" 'raster_backend=pdftoppm'

echo "==> pdf signal link candidates remain metadata only"
run_markitdown_cli normal "$LINK_INPUT" "$LINK_MD"
run_markitdown_cli --debug "$LINK_INPUT" >"$LINK_JSON"
assert_contains "$LINK_MD" 'Visit the example website for details.'
assert_not_contains "$LINK_MD" ']('
assert_contains "$LINK_JSON" '"pdf_link_candidate_count": "1"'
assert_contains "$LINK_JSON" '"pdf_link_candidates_metadata_only"'
assert_contains "$LINK_JSON" '"link_count": "1"'
assert_not_contains "$LINK_JSON" '"kind": "link"'

echo "==> pdf signal header footer candidates remain metadata only"
run_markitdown_cli normal "$HEADER_FOOTER_INPUT" "$HEADER_FOOTER_MD"
run_markitdown_cli --debug "$HEADER_FOOTER_INPUT" >"$HEADER_FOOTER_JSON"
assert_fixed_count 3 'Sample Report - Internal Use Only' "$HEADER_FOOTER_MD"
assert_fixed_count 3 'Confidential Footer - Do Not Distribute' "$HEADER_FOOTER_MD"
assert_fixed_count 3 'The core text should be preserved while noisy repeat lines are filtered.' "$HEADER_FOOTER_MD"
assert_not_contains "$HEADER_FOOTER_MD" '## Body paragraph page'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_header_footer_candidate_strategy": "conservative_v1"'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_header_candidate_count": "2"'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_footer_candidate_count": "1"'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_header_footer_candidate_count": "3"'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_header_footer_filter_policy": "disabled"'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_header_footer_filter_enabled": "false"'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_header_footer_removed_count": "0"'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_cleanup_mode": "none"'
assert_contains "$HEADER_FOOTER_JSON" '"pdf_cleanup_enabled": "false"'

echo "==> pdf signal table candidates remain metadata only"
run_markitdown_cli normal "$TABLE_INPUT" "$TABLE_MD"
run_markitdown_cli --debug "$TABLE_INPUT" >"$TABLE_JSON"
assert_contains "$TABLE_MD" 'Product Region Status'
assert_contains "$TABLE_MD" 'Alpha East Open'
assert_contains "$TABLE_MD" 'Beta West Closed'
assert_not_contains "$TABLE_MD" '| --- |'
assert_contains "$TABLE_JSON" '"pdf_table_candidate_strategy": "conservative_v1"'
assert_contains "$TABLE_JSON" '"pdf_table_row_candidate_count": "1"'
assert_contains "$TABLE_JSON" '"pdf_table_candidate_count": "0"'
assert_contains "$TABLE_JSON" '"pdf_table_reconstruction_policy": "disabled"'
assert_contains "$TABLE_JSON" '"pdf_table_reconstruction_enabled": "false"'
assert_contains "$TABLE_JSON" '"pdf_table_reconstruction_table_count": "0"'
assert_contains "$TABLE_JSON" '"pdf_table_mode": "none"'
assert_contains "$TABLE_JSON" '"pdf_table_enabled": "false"'
assert_not_contains "$TABLE_JSON" '"kind": "table"'

echo "==> pdf signal product options stay explicit opt-in and expose future promotion path"
run_markitdown_cli --debug --pdf-cleanup conservative --pdf-tables simple "$TABLE_INPUT" >"$OUT_DIR/pdf_simple_table_like_optin.json"
assert_contains "$OUT_DIR/pdf_simple_table_like_optin.json" '"pdf_cleanup_mode": "conservative"'
assert_contains "$OUT_DIR/pdf_simple_table_like_optin.json" '"pdf_cleanup_enabled": "true"'
assert_contains "$OUT_DIR/pdf_simple_table_like_optin.json" '"pdf_table_mode": "simple"'
assert_contains "$OUT_DIR/pdf_simple_table_like_optin.json" '"pdf_table_enabled": "true"'
assert_contains "$OUT_DIR/pdf_simple_table_like_optin.json" '"pdf_cleanup_opt_in_mode": "conservative"'
assert_contains "$OUT_DIR/pdf_simple_table_like_optin.json" '"pdf_table_opt_in_mode": "simple"'

cat >"$SCAN_INPUT" <<'EOF'
%PDF-1.4
1 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
2 0 obj
<< /Length 5 >>
stream
BT ET
endstream
endobj
3 0 obj
<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>
endobj
4 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
5 0 obj
<< /Type /Catalog /Pages 4 0 R >>
endobj
trailer
<< /Size 6 /Root 5 0 R >>
%%EOF
EOF

echo "==> pdf signal scanned-like boundary remains fail closed"
run_and_capture "$SCAN_ERR" run_markitdown_cli normal "$SCAN_INPUT" "$OUT_DIR/should_not_exist.md"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "scanned-like pdf must fail closed"
assert_contains "$SCAN_ERR" 'empty or not recoverable'
assert_not_contains "$SCAN_ERR" 'not configured'
assert_not_contains "$SCAN_ERR" 'image OCR provider returned a non-empty OCR model'

echo "==> pdf OCR is a dependency-backed product route"
run_and_capture "$PDF_OCR_ERR" run_markitdown_cli --ocr --ocr-lang eng "$ROOT_BASELINE_INPUT"
if [[ "$CAPTURED_STATUS" -ne 0 ]]; then
  assert_contains "$PDF_OCR_ERR" 'pdftoppm'
fi

echo "PDF SIGNAL CONTRACT PASSED"
