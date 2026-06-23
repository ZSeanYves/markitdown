#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "zip_contract")"

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

assert_mbtpdf_count_zero() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file missing: $path"
  local count
  count="$( (grep -o 'mbtpdf' "$path" || true) | wc -l | tr -d '[:space:]')"
  [[ "$count" == "0" ]] || fail "expected mbtpdf count 0 in $path, got $count"
}

assert_path_not_exists() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "unexpected path exists: $path"
}

assert_occurrence_count() {
  local path="$1"
  local needle="$2"
  local expected="$3"
  local count
  count="$( (grep -Fo -- "$needle" "$path" || true) | wc -l | tr -d '[:space:]')"
  [[ "$count" == "$expected" ]] || fail "expected $expected occurrences of $needle in $path, got $count"
}

run_and_capture() {
  local out="$1"
  shift
  set +e
  "$@" >"$out" 2>&1
  CAPTURED_STATUS=$?
  set -e
}

make_office_pdf_zip() {
  local path="$1"
  python3 - "$path" <<'PY'
import sys
import zipfile

path = sys.argv[1]
entries = {
    "supported/readme.md": "# Supported\n\nKept.\n",
    "unsupported/report.pdf": "%PDF-1.4\n",
    "unsupported/brief.docx": "fake docx\n",
    "unsupported/deck.pptx": "fake pptx\n",
    "unsupported/table.xlsx": "fake xlsx\n",
}
with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
    for name, content in entries.items():
        archive.writestr(name, content)
PY
}

make_security_zip() {
  local path="$1"
  python3 - "$path" <<'PY'
import sys
import zipfile

path = sys.argv[1]
entries = {
    "../evil.txt": "1",
    "/absolute.txt": "2",
    "C:/temp/evil.txt": "3",
    "\\\\server\\share\\evil.txt": "4",
    "safe\\dir/file.txt": "x",
    "safe/dir/file.txt": "y",
}
with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
    for name, content in entries.items():
        archive.writestr(name, content)
PY
}

make_asset_zip() {
  local path="$1"
  local image="$2"
  python3 - "$path" "$image" <<'PY'
import pathlib
import sys
import zipfile

path = sys.argv[1]
image_path = pathlib.Path(sys.argv[2])
image_bytes = image_path.read_bytes()
markdown = """# Asset Demo

![local](img/img_red.jpg)

![remote](https://example.com/remote.png)

![missing](img/missing.jpg)

![unsafe](../escape.jpg)
"""
with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
    archive.writestr("docs/readme.md", markdown)
    archive.writestr("docs/img/img_red.jpg", image_bytes)
PY
}

ZIP_INPUT="$ROOT/samples/main_process/zip/zip_basic_structured.zip"
ZIP_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_basic_structured.md"
ZIP_OUT="$OUT_DIR/zip_basic_structured.md"
ZIP_MIXED_INPUT="$ROOT/samples/main_process/zip/zip_mixed_supported_entries.zip"
ZIP_MIXED_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_mixed_supported_entries.md"
ZIP_MIXED_OUT="$OUT_DIR/zip_mixed_supported_entries.md"
ZIP_UNSUPPORTED_INPUT="$ROOT/samples/main_process/zip/zip_unsupported_entries.zip"
ZIP_UNSUPPORTED_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_unsupported_entries.md"
ZIP_UNSUPPORTED_OUT="$OUT_DIR/zip_unsupported_entries.md"
ZIP_NESTED_INPUT="$ROOT/samples/main_process/zip/zip_nested_archive_boundary.zip"
ZIP_NESTED_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_nested_archive_boundary.md"
ZIP_NESTED_OUT="$OUT_DIR/zip_nested_archive_boundary.md"
ZIP_HTML_INPUT="$ROOT/samples/main_process/zip/zip_html_local_image.zip"
ZIP_HTML_EXPECTED="$ROOT/samples/main_process/zip/expected/zip_html_local_image.md"
ZIP_HTML_OUT="$OUT_DIR/zip_html_local_image.md"
ZIP_OFFICE_PDF="$OUT_DIR/zip_unsupported_office_pdf.zip"
ZIP_OFFICE_PDF_OUT="$OUT_DIR/zip_unsupported_office_pdf.md"
ZIP_OFFICE_PDF_JSON="$OUT_DIR/zip_unsupported_office_pdf.json"
ZIP_SECURITY="$OUT_DIR/zip_security.zip"
ZIP_SECURITY_OUT="$OUT_DIR/zip_security.md"
ZIP_SECURITY_JSON="$OUT_DIR/zip_security.json"
ZIP_ASSET="$OUT_DIR/zip_asset_boundary.zip"
ZIP_ASSET_OUT_DIR="$OUT_DIR/zip_asset_boundary_out"
ZIP_ASSET_MD="$ZIP_ASSET_OUT_DIR/archive.md"
ZIP_ASSET_JSON="$OUT_DIR/zip_asset_boundary.json"
ZIP_ERR="$OUT_DIR/zip.err.txt"
CLI_HELP="$OUT_DIR/help.txt"
FORMATS_PKG="$ROOT/formats/moon.pkg"
ZIP_PKG="$ROOT/formats/zip/moon.pkg"
REGISTRY_IMPL="$ROOT/formats/registry.mbt"
ZIP_PARSER_IMPL="$ROOT/formats/zip/parser.mbt"
CLI_PKG="$ROOT/cli/moon.pkg"
DOC_PARSE_ZIP_PKG="$ROOT/format_readers/zip/moon.pkg"
RUNTIME_IMPL="$ROOT/runtime/runtime.mbt"
ZIP_README="$ROOT/samples/README.md"

echo "==> main cli zip contract stays on the promoted root pipeline foundation"
assert_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/formats/zip'
assert_contains "$ZIP_PKG" 'ZSeanYves/markitdown/format_readers/zip'
assert_contains "$ZIP_PKG" 'ZSeanYves/markitdown/container'
assert_contains "$ZIP_PKG" 'ZSeanYves/markitdown/runtime'
assert_contains "$CLI_PKG" 'ZSeanYves/markitdown/format_readers/zip'
assert_contains "$DOC_PARSE_ZIP_PKG" 'bikallem/compress/flate'
assert_contains "$REGISTRY_IMPL" '@input.DetectedFormat::Zip'
assert_contains "$REGISTRY_IMPL" '@fzip.zip_container_parser(fn() { builtin_registry() })'
assert_contains "$ZIP_PARSER_IMPL" '@dzip.open_zip'
assert_contains "$ZIP_PARSER_IMPL" '@dzip.inspect_zip_archive'
assert_contains "$ZIP_PARSER_IMPL" '@dzip.read_entry'
assert_contains "$ZIP_PARSER_IMPL" '@dzip.normalize_entry_path'
assert_contains "$ZIP_PARSER_IMPL" 'registry_provider'
assert_contains "$ZIP_PARSER_IMPL" '@runtime.parse_child_to_document'
assert_contains "$RUNTIME_IMPL" '@parser.registry_parse(registry, source, inner_context)'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/format_readers/zip'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/container'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/runtime'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/convert/zip'
assert_not_contains "$FORMATS_PKG" 'ZSeanYves/markitdown/convert/zip_core'
assert_not_contains "$CLI_PKG" 'ZSeanYves/markitdown/convert/zip'
assert_not_contains "$CLI_PKG" 'ZSeanYves/markitdown/convert/zip_core'
assert_not_contains "$REGISTRY_IMPL" '@flate'
assert_not_contains "$ZIP_PARSER_IMPL" '@flate'
assert_not_contains "$REGISTRY_IMPL" 'convert/zip'
assert_not_contains "$ZIP_PARSER_IMPL" 'convert/zip'
assert_not_contains "$REGISTRY_IMPL" 'convert/zip_core'
assert_not_contains "$ZIP_PARSER_IMPL" 'convert/zip_core'
assert_not_contains "$REGISTRY_IMPL" 'zip_raw_fallback'
assert_not_contains "$ZIP_PARSER_IMPL" 'zip_raw_fallback'
assert_not_contains "$REGISTRY_IMPL" 'zip_legacy_fallback'
assert_not_contains "$ZIP_PARSER_IMPL" 'zip_legacy_fallback'
assert_not_contains "$REGISTRY_IMPL" 'legacy_dispatcher_used'
assert_not_contains "$ZIP_PARSER_IMPL" 'legacy_dispatcher_used'
assert_not_contains "$REGISTRY_IMPL" 'convert_zip_used'
assert_not_contains "$ZIP_PARSER_IMPL" 'convert_zip_used'
assert_contains "$ZIP_README" '`format_readers/zip`'
assert_contains "$ZIP_README" '`bikallem/compress/flate`'

echo "==> main cli still exposes zip and keeps unsupported formats fail-closed"
run_and_capture "$CLI_HELP" run_markitdown_cli --help
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "--help should succeed"
assert_contains "$CLI_HELP" "Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, yml, html, htm, markdown, md, zip, epub"

echo "==> main cli zip markdown output stays root pipeline"
run_markitdown_cli normal "$ZIP_INPUT" "$ZIP_OUT"
assert_file_exists "$ZIP_OUT"
assert_matches_expected "$ZIP_EXPECTED" "$ZIP_OUT"
assert_not_contains "$ZIP_OUT" "zip_raw_fallback"
assert_not_contains "$ZIP_OUT" "zip_legacy_fallback"

echo "==> zip mixed supported entries stay next registry dispatched"
run_markitdown_cli normal "$ZIP_MIXED_INPUT" "$ZIP_MIXED_OUT"
assert_file_exists "$ZIP_MIXED_OUT"
assert_matches_expected "$ZIP_MIXED_EXPECTED" "$ZIP_MIXED_OUT"

echo "==> zip unsupported entry samples stay skipped and diagnosed"
run_markitdown_cli normal "$ZIP_UNSUPPORTED_INPUT" "$ZIP_UNSUPPORTED_OUT"
assert_file_exists "$ZIP_UNSUPPORTED_OUT"
assert_matches_expected "$ZIP_UNSUPPORTED_EXPECTED" "$ZIP_UNSUPPORTED_OUT"

echo "==> nested archive samples stay non-recursive"
run_markitdown_cli normal "$ZIP_NESTED_INPUT" "$ZIP_NESTED_OUT"
assert_file_exists "$ZIP_NESTED_OUT"
assert_matches_expected "$ZIP_NESTED_EXPECTED" "$ZIP_NESTED_OUT"

echo "==> zip output boundary materializes only local assets"
run_markitdown_cli normal "$ZIP_HTML_INPUT" "$ZIP_HTML_OUT"
assert_file_exists "$ZIP_HTML_OUT"
assert_matches_expected "$ZIP_HTML_EXPECTED" "$ZIP_HTML_OUT"
assert_file_exists "$OUT_DIR/assets/archive/site_page.html/image01.png"
assert_path_not_exists "$OUT_DIR/assets/archive/site_page.html/image02.png"

echo "==> zip unsupported inner office and pdf entries stay fail-closed"
make_office_pdf_zip "$ZIP_OFFICE_PDF"
run_and_capture "$ZIP_OFFICE_PDF_JSON" run_markitdown_cli --json "$ZIP_OFFICE_PDF"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "zip office/pdf debug json should succeed"
assert_contains "$ZIP_OFFICE_PDF_JSON" '"detected_format": "zip"'
assert_contains "$ZIP_OFFICE_PDF_JSON" '"unsupported_entry_count": "4"'
assert_contains "$ZIP_OFFICE_PDF_JSON" '"event_granularity": "archive_entry"'
run_markitdown_cli normal "$ZIP_OFFICE_PDF" "$ZIP_OFFICE_PDF_OUT"
assert_contains "$ZIP_OFFICE_PDF_OUT" "# supported/readme.md"
assert_contains "$ZIP_OFFICE_PDF_OUT" "Skipped: unsupported file type: pdf"
assert_contains "$ZIP_OFFICE_PDF_OUT" "Skipped: unsupported file type: docx"
assert_contains "$ZIP_OFFICE_PDF_OUT" "Skipped: unsupported file type: pptx"
assert_contains "$ZIP_OFFICE_PDF_OUT" "Skipped: unsupported file type: xlsx"

echo "==> zip security boundaries keep unsafe and duplicate paths diagnosed"
make_security_zip "$ZIP_SECURITY"
run_and_capture "$ZIP_SECURITY_JSON" run_markitdown_cli --json "$ZIP_SECURITY"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "zip security debug json should succeed"
assert_contains "$ZIP_SECURITY_JSON" '"path_traversal_count": "4"'
assert_contains "$ZIP_SECURITY_JSON" '"duplicate_path_count": "2"'
run_markitdown_cli normal "$ZIP_SECURITY" "$ZIP_SECURITY_OUT"
assert_occurrence_count "$ZIP_SECURITY_OUT" "Skipped: unsafe entry path" 4
assert_occurrence_count "$ZIP_SECURITY_OUT" "Skipped: duplicate normalized entry path: safe/dir/file.txt" 2

echo "==> zip asset boundary keeps remote missing and traversal refs outside materialization"
make_asset_zip "$ZIP_ASSET" "$ROOT/samples/main_process/html/assets/img/img_red.jpg"
mkdir -p "$ZIP_ASSET_OUT_DIR"
run_and_capture "$ZIP_ASSET_JSON" run_markitdown_cli --json "$ZIP_ASSET"
[[ "$CAPTURED_STATUS" -eq 0 ]] || fail "zip asset debug json should succeed"
assert_contains "$ZIP_ASSET_JSON" 'zip asset entry missing for'
assert_contains "$ZIP_ASSET_JSON" 'zip asset path rejected for entry'
run_markitdown_cli normal "$ZIP_ASSET" "$ZIP_ASSET_MD"
assert_contains "$ZIP_ASSET_MD" "![local](assets/archive/docs_readme.md/image01.jpg)"
assert_contains "$ZIP_ASSET_MD" "![remote](https://example.com/remote.png)"
assert_contains "$ZIP_ASSET_MD" "missing"
assert_contains "$ZIP_ASSET_MD" "unsafe"
assert_not_contains "$ZIP_ASSET_MD" "missing.jpg"
assert_not_contains "$ZIP_ASSET_MD" "escape.jpg"
assert_file_exists "$ZIP_ASSET_OUT_DIR/assets/archive/docs_readme.md/image01.jpg"
assert_path_not_exists "$ZIP_ASSET_OUT_DIR/assets/archive/docs_readme.md/image02.jpg"
assert_path_not_exists "$ZIP_ASSET_OUT_DIR/assets/archive/docs_readme.md/missing.jpg"
assert_path_not_exists "$ZIP_ASSET_OUT_DIR/assets/archive/docs_readme.md/escape.jpg"

echo "ZIP CONTRACT PASSED"
