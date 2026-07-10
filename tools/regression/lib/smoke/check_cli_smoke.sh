#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
source "$ROOT/tools/regression/lib/shared/tmp.sh"
source "$ROOT/tools/regression/lib/shared/cli_runner.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/tests/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "cli_smoke")"

trap 'status=$?; sample_cleanup_tmp_dir "$OUT_DIR"; exit "$status"' EXIT

resolve_markitdown_cli
echo "runner: $(markitdown_runner_command_prefix)"

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

TXT_INPUT="$ROOT/samples/fixtures/contracts/txt/txt_plain.txt"
TXT_EXPECTED="$ROOT/samples/fixtures/contracts/txt/txt_plain.expected.md"
CSV_INPUT="$ROOT/samples/fixtures/contracts/csv/csv_basic.csv"
CSV_EXPECTED="$ROOT/samples/fixtures/contracts/csv/csv_basic.expected.md"
TSV_INPUT="$ROOT/samples/fixtures/contracts/tsv/tsv_basic.tsv"
TSV_EXPECTED="$ROOT/samples/fixtures/contracts/tsv/tsv_basic.expected.md"
DOCX_INPUT="$ROOT/samples/fixtures/contracts/docx/docx_image_alt_title_basic.docx"
PDF_INPUT="$ROOT/samples/fixtures/contracts/pdf/root_native_text_baseline.pdf"
MARKDOWN_INPUT="$ROOT/samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md"
JSON_INPUT="$ROOT/samples/fixtures/contracts/json/json_object_basic.json"
JSON_EXPECTED="$ROOT/samples/fixtures/contracts/json/json_object_basic.expected.md"
OCR_INPUT="$ROOT/samples/fixtures/contracts/ocr/ocr_tiny_png.png"
OCR_EXPECTED="$ROOT/samples/fixtures/contracts/ocr/ocr_tiny_png.expected.md"
MARKDOWN_EXPECTED="$ROOT/samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.expected.md"

NO_META_DIR="$OUT_DIR/no_meta"
STDOUT_DIR="$OUT_DIR/stdout"
mkdir -p "$STDOUT_DIR"

HELP_STDOUT="$STDOUT_DIR/help.txt"
HELP_ALIAS_STDOUT="$STDOUT_DIR/help_alias.txt"
HELP_SHORT_STDOUT="$STDOUT_DIR/help_short.txt"
VERSION_STDOUT="$STDOUT_DIR/version.txt"
VERSION_ALIAS_STDOUT="$STDOUT_DIR/version_alias.txt"
PDF_ERR="$STDOUT_DIR/pdf.err.txt"
JSON_STDOUT="$STDOUT_DIR/txt.json"
JSON_MD="$NO_META_DIR/json_object_basic.md"
MARKDOWN_MD="$NO_META_DIR/markdown_basic_heading_paragraph.md"
OCR_MD="$NO_META_DIR/ocr_tiny_png.md"

TXT_MD="$NO_META_DIR/txt_plain.md"
CSV_MD="$NO_META_DIR/csv_basic.md"
TSV_MD="$NO_META_DIR/tsv_basic.md"
TXT_ALIAS_MD="$NO_META_DIR/txt_plain_alias.md"

echo "==> help and version expose stable product anchors"
run_and_capture "$HELP_STDOUT" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$HELP_STDOUT" 'markitdown-mb [balance|accurate|stream] [--format <format>] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--provenance-out <path>] <input> [output]'
assert_contains "$HELP_STDOUT" 'Capability groups: Core, Office, Containers, Media, PdfOcr.'
assert_contains "$HELP_STDOUT" 'All other formats fail closed in this build.'

run_and_capture "$HELP_ALIAS_STDOUT" run_markitdown_cli help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "help alias should succeed"
assert_contains "$HELP_ALIAS_STDOUT" 'markitdown-mb help | --help | -h'

run_and_capture "$HELP_SHORT_STDOUT" run_markitdown_cli -h
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "-h should succeed"
assert_contains "$HELP_SHORT_STDOUT" 'markitdown-mb version | --version'

run_and_capture "$VERSION_STDOUT" run_markitdown_cli --version
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--version should succeed"
assert_contains "$VERSION_STDOUT" 'markitdown-mb 0.5.0'

run_and_capture "$VERSION_ALIAS_STDOUT" run_markitdown_cli version
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "version alias should succeed"
assert_matches_expected "$VERSION_STDOUT" "$VERSION_ALIAS_STDOUT"

echo "==> representative product routes succeed"
run_markitdown_cli balance "$TXT_INPUT" "$TXT_MD"
run_markitdown_cli balance "$CSV_INPUT" "$CSV_MD"
run_markitdown_cli balance "$TSV_INPUT" "$TSV_MD"
run_markitdown_cli balance "$JSON_INPUT" "$JSON_MD"
run_markitdown_cli balance "$MARKDOWN_INPUT" "$MARKDOWN_MD"
run_markitdown_cli balance "$OCR_INPUT" "$OCR_MD"
assert_matches_expected "$TXT_EXPECTED" "$TXT_MD"
assert_matches_expected "$CSV_EXPECTED" "$CSV_MD"
assert_matches_expected "$TSV_EXPECTED" "$TSV_MD"
assert_matches_expected "$JSON_EXPECTED" "$JSON_MD"
assert_matches_expected "$MARKDOWN_EXPECTED" "$MARKDOWN_MD"
assert_matches_expected "$OCR_EXPECTED" "$OCR_MD"
assert_file_not_exists "$NO_META_DIR/metadata/txt_plain.metadata.json"

echo "==> bare invocation still maps to balance"
run_markitdown_cli "$TXT_INPUT" "$TXT_ALIAS_MD"
assert_matches_expected "$TXT_EXPECTED" "$TXT_ALIAS_MD"

echo "==> debug json remains available on the main cli"
run_and_capture "$JSON_STDOUT" run_markitdown_cli --debug "$TXT_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--debug txt should succeed"
assert_contains "$JSON_STDOUT" '"renderer_name": "DebugJsonRenderer"'
assert_contains "$JSON_STDOUT" '"source_ref"'

echo "==> rag json remains available on the main cli"
run_and_capture "$JSON_STDOUT" run_markitdown_cli --rag "$TXT_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--rag txt should succeed"
assert_contains "$JSON_STDOUT" '"output_format": "rag_json"'
assert_contains "$JSON_STDOUT" '"chunks"'

echo "==> pdf OCR is a dependency-backed product path"
run_and_capture "$PDF_ERR" run_markitdown_cli --ocr --ocr-lang eng "$PDF_INPUT"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "balanced PDF OCR should fail closed"
assert_contains "$PDF_ERR" 'PDF OCR is only available through the `accurate` PDF layout route'

echo "==> retired PDF product options fail closed"
run_and_capture "$PDF_ERR" run_markitdown_cli --pdf-cleanup conservative "$PDF_INPUT" "$NO_META_DIR/root_native_text_baseline_optin.md"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "removed --pdf-cleanup should fail"
assert_contains "$PDF_ERR" 'unsupported option: --pdf-cleanup'

echo "CLI SMOKE PASSED"
