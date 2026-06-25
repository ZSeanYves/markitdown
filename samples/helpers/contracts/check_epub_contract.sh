#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "epub_contract")"

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

assert_path_not_exists() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "unexpected path exists: $path"
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

EPUB_INPUT="$ROOT/samples/main_process/epub/markdown/epub_basic_package.epub"
EPUB_EXPECTED="$ROOT/samples/main_process/epub/expected/markdown/epub_basic_package.md"
EPUB_OUT="$OUT_DIR/epub_basic_package.md"
EPUB_SPINE_INPUT="$ROOT/samples/main_process/epub/markdown/epub_spine_order.epub"
EPUB_SPINE_EXPECTED="$ROOT/samples/main_process/epub/expected/markdown/epub_spine_order.md"
EPUB_SPINE_OUT="$OUT_DIR/epub_spine_order.md"
EPUB_MISSING_INPUT="$ROOT/samples/main_process/epub/markdown/epub_spine_missing_item_boundary.epub"
EPUB_MISSING_EXPECTED="$ROOT/samples/main_process/epub/expected/markdown/epub_spine_missing_item_boundary.md"
EPUB_MISSING_OUT="$OUT_DIR/epub_spine_missing_item_boundary.md"
EPUB_UNSUPPORTED_INPUT="$ROOT/samples/main_process/epub/markdown/epub_unsupported_spine_warning.epub"
EPUB_UNSUPPORTED_EXPECTED="$ROOT/samples/main_process/epub/expected/markdown/epub_unsupported_spine_warning.md"
EPUB_UNSUPPORTED_OUT="$OUT_DIR/epub_unsupported_spine_warning.md"
EPUB_LOCAL_ASSET_INPUT="$ROOT/samples/main_process/epub/assets/epub_local_image_basic.epub"
EPUB_LOCAL_ASSET_EXPECTED="$ROOT/samples/main_process/epub/expected/assets/epub_local_image_basic/result.md"
EPUB_LOCAL_ASSET_OUT="$OUT_DIR/epub_local_image_basic.md"
EPUB_REMOTE_INPUT="$ROOT/samples/main_process/epub/markdown/epub_remote_data_image_boundary.epub"
EPUB_REMOTE_EXPECTED="$ROOT/samples/main_process/epub/expected/markdown/epub_remote_data_image_boundary.md"
EPUB_REMOTE_OUT="$OUT_DIR/epub_remote_data_image_boundary.md"
EPUB_SPINE_JSON="$OUT_DIR/epub_spine_order.json"
EPUB_MISSING_JSON="$OUT_DIR/epub_spine_missing_item_boundary.json"
EPUB_REMOTE_JSON="$OUT_DIR/epub_remote_data_image_boundary.json"
CLI_HELP="$OUT_DIR/help.txt"
FORMATS_PKG="$ROOT/formats/moon.pkg"
EPUB_PKG="$ROOT/formats/epub/moon.pkg"
HTML_PKG="$ROOT/formats/html/moon.pkg"
CLI_PKG="$ROOT/cli/moon.pkg"
REGISTRY_IMPL="$ROOT/formats/registry.mbt"
EPUB_PARSER_IMPL="$ROOT/formats/epub/parser.mbt"
DOC_PARSE_EPUB_PKG="$ROOT/format_readers/epub/moon.pkg"
DOC_PARSE_ZIP_PKG="$ROOT/format_readers/zip/moon.pkg"
RUNTIME_IMPL="$ROOT/runtime/runtime.mbt"
README_DOC="$ROOT/README.md"

echo "==> main cli epub contract stays on the promoted root pipeline foundation"
assert_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/formats/epub'
assert_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/formats/html'
assert_contains "$EPUB_PKG" 'ZSeanYves/markitdown/format_readers/epub'
assert_contains "$EPUB_PKG" 'ZSeanYves/markitdown/runtime'
assert_contains "$HTML_PKG" 'ZSeanYves/markitdown/format_readers/html'
assert_contains "$HTML_PKG" 'ZSeanYves/markitdown/pipeline'
assert_contains "$DOC_PARSE_EPUB_PKG" 'ZSeanYves/markitdown/format_readers/zip'
assert_contains "$DOC_PARSE_ZIP_PKG" 'bikallem/compress/flate'
assert_contains "$REGISTRY_IMPL" '@input.DetectedFormat::Epub'
assert_contains "$REGISTRY_IMPL" '@fepub.epub_container_parser(fn() { builtin_registry() })'
assert_contains "$REGISTRY_IMPL" '@input.DetectedFormat::Html'
assert_contains "$REGISTRY_IMPL" '@fhtml.html_lite_parser()'
assert_contains "$EPUB_PARSER_IMPL" '@depub.open_epub_package'
assert_contains "$EPUB_PARSER_IMPL" '@depub.inspect_epub_package'
assert_contains "$EPUB_PARSER_IMPL" '@depub.read_part_bytes'
assert_contains "$EPUB_PARSER_IMPL" 'registry_provider'
assert_contains "$EPUB_PARSER_IMPL" '@runtime.parse_child_to_document'
assert_contains "$RUNTIME_IMPL" '@parser.registry_parse(registry, source, inner_context)'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/format_readers/epub'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/format_readers/zip'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/format_readers/html'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/pipeline'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/runtime'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/convert/epub'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/convert/html'
assert_not_contains "$CLI_PKG" 'ZSeanYves/markitdown/convert/epub'
assert_not_contains "$CLI_PKG" 'ZSeanYves/markitdown/convert/html'
assert_not_contains "$REGISTRY_IMPL" 'convert/epub'
assert_not_contains "$EPUB_PARSER_IMPL" 'convert/epub'
assert_not_contains "$REGISTRY_IMPL" 'convert/html'
assert_not_contains "$EPUB_PARSER_IMPL" 'convert/html'
assert_not_contains "$REGISTRY_IMPL" 'epub_raw_fallback'
assert_not_contains "$EPUB_PARSER_IMPL" 'epub_raw_fallback'
assert_not_contains "$REGISTRY_IMPL" 'epub_legacy_fallback'
assert_not_contains "$EPUB_PARSER_IMPL" 'epub_legacy_fallback'
assert_not_contains "$REGISTRY_IMPL" 'legacy_dispatcher_used'
assert_not_contains "$EPUB_PARSER_IMPL" 'legacy_dispatcher_used'
assert_not_contains "$REGISTRY_IMPL" 'convert_epub_used'
assert_not_contains "$EPUB_PARSER_IMPL" 'convert_epub_used'
assert_not_contains "$REGISTRY_IMPL" 'convert_html_used'
assert_not_contains "$EPUB_PARSER_IMPL" 'convert_html_used'
assert_contains "$README_DOC" 'EPUB restoration is implemented through `format_readers/epub` on top of `format_readers/zip`'

echo "==> help keeps epub exposed and fail-closed unsupported formats"
run_and_capture "$CLI_HELP" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$CLI_HELP" "Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, yml, html, htm, markdown, md, zip, epub"

echo "==> main cli epub markdown output stays root pipeline"
run_markitdown_cli normal "$EPUB_INPUT" "$EPUB_OUT"
assert_file_exists "$EPUB_OUT"
assert_matches_expected "$EPUB_EXPECTED" "$EPUB_OUT"
assert_not_contains "$EPUB_OUT" "epub_raw_fallback"
assert_not_contains "$EPUB_OUT" "epub_legacy_fallback"

echo "==> epub reading order stays opf spine order"
run_markitdown_cli normal "$EPUB_SPINE_INPUT" "$EPUB_SPINE_OUT"
assert_file_exists "$EPUB_SPINE_OUT"
assert_matches_expected "$EPUB_SPINE_EXPECTED" "$EPUB_SPINE_OUT"
run_and_capture "$EPUB_SPINE_JSON" run_markitdown_cli --debug "$EPUB_SPINE_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "epub spine debug json should succeed"
assert_contains "$EPUB_SPINE_JSON" '"event_granularity": "epub_spine_item"'
assert_contains "$EPUB_SPINE_JSON" '"effective_mode": "container_recursive"'
assert_contains "$EPUB_SPINE_JSON" '"ir_input_kind": "container_plan"'
assert_contains "$EPUB_SPINE_JSON" '"entry_path": "OPS/text/chapter-02.xhtml"'
assert_contains "$EPUB_SPINE_JSON" '"entry_path": "OPS/text/chapter-01.xhtml"'

echo "==> epub missing and unsupported spine items stay diagnosed"
run_markitdown_cli normal "$EPUB_MISSING_INPUT" "$EPUB_MISSING_OUT"
assert_file_exists "$EPUB_MISSING_OUT"
assert_matches_expected "$EPUB_MISSING_EXPECTED" "$EPUB_MISSING_OUT"
run_and_capture "$EPUB_MISSING_JSON" run_markitdown_cli --debug "$EPUB_MISSING_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "epub missing spine debug json should succeed"
assert_contains "$EPUB_MISSING_JSON" '"missing_manifest_item_count": "1"'
assert_contains "$EPUB_MISSING_JSON" '"missing_spine_item_count": "1"'
assert_contains "$EPUB_MISSING_JSON" '"skipped_entry_count": "1"'
assert_contains "$EPUB_MISSING_JSON" 'Skipped: spine item references missing manifest item: missing'

run_markitdown_cli normal "$EPUB_UNSUPPORTED_INPUT" "$EPUB_UNSUPPORTED_OUT"
assert_file_exists "$EPUB_UNSUPPORTED_OUT"
assert_matches_expected "$EPUB_UNSUPPORTED_EXPECTED" "$EPUB_UNSUPPORTED_OUT"

echo "==> epub output boundary materializes only local archive assets"
run_markitdown_cli normal "$EPUB_LOCAL_ASSET_INPUT" "$EPUB_LOCAL_ASSET_OUT"
assert_file_exists "$EPUB_LOCAL_ASSET_OUT"
assert_matches_expected "$EPUB_LOCAL_ASSET_EXPECTED" "$EPUB_LOCAL_ASSET_OUT"
assert_file_exists "$OUT_DIR/assets/archive/OPS_chapter.xhtml/image01.png"

echo "==> epub remote and data assets stay no-fetch no-persist"
run_markitdown_cli normal "$EPUB_REMOTE_INPUT" "$EPUB_REMOTE_OUT"
assert_file_exists "$EPUB_REMOTE_OUT"
assert_matches_expected "$EPUB_REMOTE_EXPECTED" "$EPUB_REMOTE_OUT"
assert_path_not_exists "$OUT_DIR/assets/archive/OPS_chapter.xhtml/image02.png"
run_and_capture "$EPUB_REMOTE_JSON" run_markitdown_cli --debug "$EPUB_REMOTE_INPUT"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "epub remote debug json should succeed"
assert_contains "$EPUB_REMOTE_JSON" '"asset_count": "0"'
assert_contains "$EPUB_REMOTE_JSON" 'html_remote_image_reference_only'
assert_contains "$EPUB_REMOTE_JSON" 'html_data_image_reference_only'
assert_not_contains "$EPUB_REMOTE_OUT" 'https://example.com/a.png'
assert_not_contains "$EPUB_REMOTE_OUT" 'data:image/png'

echo "EPUB CONTRACT PASSED"
