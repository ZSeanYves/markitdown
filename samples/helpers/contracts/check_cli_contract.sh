#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp.sh"
source "$ROOT/samples/helpers/shared/cli_runner.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/tests/check}"
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

TXT_INPUT="$ROOT/samples/fixtures/contracts/txt/txt_plain.txt"
TXT_EXPECTED="$ROOT/samples/fixtures/contracts/txt/txt_plain.expected.md"
CSV_INPUT="$ROOT/samples/fixtures/contracts/csv/csv_basic.csv"
CSV_EXPECTED="$ROOT/samples/fixtures/contracts/csv/csv_basic.expected.md"
TSV_INPUT="$ROOT/samples/fixtures/contracts/tsv/tsv_basic.tsv"
TSV_EXPECTED="$ROOT/samples/fixtures/contracts/tsv/tsv_basic.expected.md"
DOCX_INPUT="$ROOT/samples/fixtures/contracts/docx/docx_image_alt_title_basic.docx"
DOCX_EXPECTED="$ROOT/samples/fixtures/contracts/docx/docx_image_alt_title_basic.result.md"
PPTX_INPUT="$ROOT/samples/fixtures/contracts/pptx/pptx_hidden_slide_basic.pptx"
XLSX_INPUT="$ROOT/samples/fixtures/contracts/xlsx/sheet_simple.xlsx"
ZIP_INPUT="$ROOT/samples/fixtures/contracts/zip/zip_basic_structured.zip"
ZIP_EXPECTED="$ROOT/samples/fixtures/contracts/zip/zip_basic_structured.expected.md"
EPUB_INPUT="$ROOT/samples/fixtures/contracts/epub/epub_basic_package.epub"
PDF_INPUT="$ROOT/samples/fixtures/contracts/pdf/root_native_text_baseline.pdf"
MD_INPUT="$ROOT/samples/fixtures/contracts/markdown/markdown_heading.md"
MARKDOWN_INPUT="$ROOT/samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md"
MARKDOWN_DOT_INPUT="$ROOT/samples/fixtures/contracts/markdown/markdown_frontmatter_passthrough.markdown"
HTML_INPUT="$ROOT/samples/fixtures/contracts/html/html_simple.html"
JSON_INPUT="$ROOT/samples/fixtures/contracts/json/json_object_basic.json"
JSON_EXPECTED="$ROOT/samples/fixtures/contracts/json/json_object_basic.expected.md"
JSONL_INPUT="$ROOT/samples/fixtures/contracts/jsonl/jsonl_records_basic.jsonl"
JSONL_EXPECTED="$ROOT/samples/fixtures/contracts/jsonl/jsonl_records_basic.expected.md"
NDJSON_INPUT="$ROOT/samples/fixtures/contracts/ndjson/ndjson_records_basic.ndjson"
NDJSON_EXPECTED="$ROOT/samples/fixtures/contracts/ndjson/ndjson_records_basic.expected.md"
XML_INPUT="$ROOT/samples/fixtures/contracts/xml/xml_basic.xml"
XML_EXPECTED="$ROOT/samples/fixtures/contracts/xml/xml_basic.expected.md"
YAML_INPUT="$ROOT/samples/fixtures/contracts/yaml/yaml_mapping_basic.yaml"
YAML_EXPECTED="$ROOT/samples/fixtures/contracts/yaml/yaml_mapping_basic.expected.md"
TOML_INPUT="$ROOT/samples/fixtures/contracts/toml/toml_object_basic.toml"
TOML_EXPECTED="$ROOT/samples/fixtures/contracts/toml/toml_object_basic.expected.md"
IPYNB_INPUT="$ROOT/samples/fixtures/contracts/ipynb/ipynb_markdown_basic.ipynb"
IPYNB_EXPECTED="$ROOT/samples/fixtures/contracts/ipynb/ipynb_markdown_basic.expected.md"
OCR_INPUT="$ROOT/samples/fixtures/contracts/ocr/ocr_tiny_png.png"
OCR_EXPECTED="$ROOT/samples/fixtures/contracts/ocr/ocr_tiny_png.expected.md"
MARKDOWN_EXPECTED="$ROOT/samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.expected.md"
MARKDOWN_DOT_EXPECTED="$ROOT/samples/fixtures/contracts/markdown/markdown_frontmatter_passthrough.expected.md"

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
assert_contains "$HELP_STDOUT" 'markitdown-mb [balance|accurate|stream] [--format txt|csv|tsv|srt|vtt|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|eml|msg|tex|latex|rst|adoc|asciidoc|zip|epub|odt|ods|odp|docx|xlsx|pptx|pdf|wav|mp3|m4a|png|jpg|jpeg|bmp|webp|tif|tiff] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--provenance-out <path>] <input> [output]'
assert_contains "$HELP_STDOUT" '--audio-lang <LANG>'
assert_contains "$HELP_STDOUT" 'Omit the mode or use `balance` for the default strategy mode.'
assert_contains "$HELP_STDOUT" '`accurate` selects the Accurate strategy mode while preserving the selected output view.'
assert_contains "$HELP_STDOUT" '`stream` selects the Stream strategy mode and explicitly requests a format'
assert_contains "$HELP_STDOUT" 'Direct image input uses local Tesseract OCR by default; `--no-ocr` disables it. On PDF input, `--ocr` enables the explicit balanced OCR path, while `accurate` defaults to scanned-like OCR upgrades before entering the Paddle-backed accurate route.'
assert_contains "$HELP_STDOUT" 'Audio transcription uses an optional local backend. The official wrapper is `samples/env/audio/audio_transcribe_wrapper.py`, which drives local `Vosk`; if `MARKITDOWN_AUDIO_CMD` is unset, the runtime prefers the repo-local virtualenv under `./env/` and otherwise falls back to `python3`.'
assert_contains "$HELP_STDOUT" 'Use `--audio-lang <LANG>` to pass a language hint, set `MARKITDOWN_AUDIO_MODEL_PATH` to the extracted Vosk model directory, and install local `ffmpeg` when compressed audio needs normalization.'
assert_contains "$HELP_STDOUT" '`--provenance-out` is available only on single-file runs; batch mode always writes `manifest.json` to the output directory instead.'
assert_contains "$HELP_STDOUT" '`--rag` switches the output view to chunked retrieval JSON with the default internal chunking policy.'
assert_contains "$HELP_STDOUT" 'Supported product formats: txt, csv, tsv, srt, vtt, json, jsonl, ndjson, ipynb, xml, yaml, yml, toml, html, htm, markdown, md, eml, msg, tex, latex, rst, adoc, asciidoc, zip, epub, odt, ods, odp, docx, xlsx, pptx, pdf, wav, mp3, m4a, png, jpg, jpeg, bmp, webp, tif, tiff'
assert_contains "$HELP_STDOUT" 'fail closed'

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

echo "==> txt csv tsv json jsonl ndjson ipynb xml yaml toml html markdown zip epub odt ods odp docx xlsx pptx pdf wav mp3 m4a and ocr succeed through main product cli"
run_markitdown_cli balance "$TXT_INPUT" "$TXT_MD"
run_markitdown_cli balance "$CSV_INPUT" "$CSV_MD"
run_markitdown_cli balance "$TSV_INPUT" "$TSV_MD"
run_markitdown_cli balance "$JSON_INPUT" "$JSON_MD"
run_markitdown_cli balance "$JSONL_INPUT" "$JSONL_MD"
run_markitdown_cli balance "$NDJSON_INPUT" "$NDJSON_MD"
run_markitdown_cli balance "$IPYNB_INPUT" "$IPYNB_MD"
run_markitdown_cli balance "$XML_INPUT" "$XML_MD"
run_markitdown_cli balance "$YAML_INPUT" "$YAML_MD"
run_markitdown_cli balance "$TOML_INPUT" "$TOML_MD"
run_markitdown_cli balance "$HTML_INPUT" "$HTML_MD"
run_markitdown_cli balance "$MARKDOWN_INPUT" "$MARKDOWN_MD"
run_markitdown_cli balance "$MARKDOWN_DOT_INPUT" "$MARKDOWN_DOT_MD"
run_markitdown_cli balance "$ZIP_INPUT" "$ZIP_MD"
run_markitdown_cli balance "$EPUB_INPUT" "$EPUB_MD"
run_markitdown_cli balance "$DOCX_INPUT" "$DOCX_MD"
run_markitdown_cli balance "$XLSX_INPUT" "$XLSX_MD"
run_markitdown_cli balance "$PPTX_INPUT" "$NO_META_DIR/pptx_hidden_slide_basic.md"
run_markitdown_cli balance "$PDF_INPUT" "$NO_META_DIR/root_native_text_baseline.md"
run_markitdown_cli balance "$OCR_INPUT" "$OCR_MD"
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
assert_matches_expected "$ROOT/samples/fixtures/contracts/html/html_simple.expected.md" "$HTML_MD"
assert_matches_expected "$MARKDOWN_EXPECTED" "$MARKDOWN_MD"
assert_matches_expected "$MARKDOWN_DOT_EXPECTED" "$MARKDOWN_DOT_MD"
assert_matches_expected "$ZIP_EXPECTED" "$ZIP_MD"
assert_matches_expected "$ROOT/samples/fixtures/contracts/epub/epub_basic_package.expected.md" "$EPUB_MD"
assert_matches_expected "$DOCX_EXPECTED" "$DOCX_MD"
assert_matches_expected "$ROOT/samples/fixtures/contracts/xlsx/sheet_simple.expected.md" "$XLSX_MD"
assert_matches_expected "$ROOT/samples/fixtures/contracts/pptx/pptx_hidden_slide_basic.expected.md" "$NO_META_DIR/pptx_hidden_slide_basic.md"
assert_matches_expected "$ROOT/samples/fixtures/contracts/pdf/root_native_text_baseline.expected.md" "$NO_META_DIR/root_native_text_baseline.md"
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

echo "==> removed PDF product options fail with migration guidance"
run_and_capture "$PDF_ERR" run_markitdown_cli --pdf-cleanup conservative "$PDF_INPUT" "$NO_META_DIR/root_native_text_baseline_optin.md"
[[ "$CAPTURED_STATUS" -ne 0 ]] || fail "removed --pdf-cleanup should fail"
assert_contains "$PDF_ERR" '`--pdf-cleanup` was removed from the main CLI'

echo "CLI CONTRACT PASSED"
