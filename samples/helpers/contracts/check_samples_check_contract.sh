#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/tests/check}"
mkdir -p "$TMP_ROOT"
OUT_DIR="$(mktemp -d "$TMP_ROOT/check_contract.XXXXXX")"

trap 'status=$?; rm -rf "$OUT_DIR"; exit "$status"' EXIT

# Architecture/doc guard anchors:
# formats=txt,csv,tsv,srt,vtt,json,jsonl,ndjson,ipynb,xml,yaml,toml,html,markdown,eml,tex,rst,asciidoc,zip,epub,odt,ods,odp,docx,xlsx,pptx,pdf,wav,mp3,m4a,ocr
# formats=markdown
# formats=docx
# formats=xlsx
# formats=pptx
# formats=pdf

fail() {
  echo "[fail] $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

assert_not_exists() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "expected path to be absent: $path"
}

LAB_ROOT="$OUT_DIR/markitdown-quality-lab"
MAIN_ROOT="$LAB_ROOT/external_main_process"
mkdir -p "$MAIN_ROOT/txt/markdown" "$MAIN_ROOT/txt/rag" "$MAIN_ROOT/txt/expected/markdown" "$MAIN_ROOT/txt/expected/rag"

cp "$ROOT/samples/fixtures/contracts/txt/txt_plain.txt" "$MAIN_ROOT/txt/markdown/txt_plain.txt"
cp "$ROOT/samples/fixtures/contracts/txt/txt_plain.txt" "$MAIN_ROOT/txt/rag/txt_plain.txt"
cp "$ROOT/samples/fixtures/contracts/txt/txt_plain.expected.md" "$MAIN_ROOT/txt/expected/markdown/txt_plain.md"
cat >"$MAIN_ROOT/txt/expected/rag/txt_plain.rag.json" <<'EOF'
{
  "output_format": "rag_json",
  "detected_format": "txt",
  "parser_mode": "streaming_event",
  "convert_mode": "balanced",
  "chunk_count": { "exact": 1 },
  "chunks": [
    {
      "kind": "text",
      "text_contains_all": ["Alpha Beta"]
    }
  ]
}
EOF

cat >"$MAIN_ROOT/MANIFEST.tsv" <<'EOF'
id	format	lane	input_path	expected_path	notes
txt_markdown_txt_plain	txt	markdown	txt/markdown/txt_plain.txt	txt/expected/markdown/txt_plain.md	contract markdown sample
txt_rag_txt_plain	txt	rag	txt/rag/txt_plain.txt	txt/expected/rag/txt_plain.rag.json	contract rag sample
EOF

RUN_LOG="$OUT_DIR/run.log"
DIFF_LOG="$OUT_DIR/diff.log"
FAIL_LOG="$OUT_DIR/fail.log"
MISSING_LOG="$OUT_DIR/missing.log"

(
  cd "$ROOT"
  MARKITDOWN_CHECK_TMP_ROOT="$ROOT/.tmp/tests/check" \
  MARKITDOWN_TMP_DIR="$ROOT/.tmp/tests/check" \
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  MARKITDOWN_QUALITY_LAB="$LAB_ROOT" \
  ./samples/check.sh --format txt
) >"$RUN_LOG" 2>&1

assert_contains "$RUN_LOG" "result: pass"
assert_contains "$RUN_LOG" "formats=txt"

RUN_DIR="$(sed -n 's/^run: //p' "$RUN_LOG" | tail -1)"
[[ -n "$RUN_DIR" ]] || fail "missing run directory in output"

SUMMARY_TSV="$ROOT/$RUN_DIR/summary.tsv"
SUMMARY_MD="$ROOT/$RUN_DIR/summary.md"
MARKDOWN_LOG="$ROOT/$RUN_DIR/logs/markdown.entrypoint.log"
RAG_LOG="$ROOT/$RUN_DIR/logs/rag.entrypoint.log"
ASSETS_LOG="$ROOT/$RUN_DIR/logs/assets.entrypoint.log"

[[ -f "$SUMMARY_TSV" ]] || fail "missing summary.tsv"
[[ -f "$SUMMARY_MD" ]] || fail "missing summary.md"
[[ -f "$MARKDOWN_LOG" ]] || fail "missing markdown entrypoint log"
[[ -f "$RAG_LOG" ]] || fail "missing rag entrypoint log"
[[ -f "$ASSETS_LOG" ]] || fail "missing assets entrypoint log"

assert_contains "$SUMMARY_TSV" $'markdown\ttxt\tpass\tprebuilt\t1\t0\t'
assert_contains "$SUMMARY_TSV" $'rag\ttxt\tpass\tprebuilt\t1\t0\t'
assert_contains "$SUMMARY_TSV" $'assets\ttxt\tpass\tprebuilt\t0\t0\t'
assert_contains "$SUMMARY_MD" "Runner: prebuilt"
assert_contains "$SUMMARY_MD" "Lanes: markdown, rag, assets"
assert_contains "$SUMMARY_MD" "- Formats: txt"
assert_contains "$SUMMARY_MD" "- Failed: 0"
assert_contains "$SUMMARY_MD" "- Workspace scratch:"
assert_contains "$SUMMARY_MD" "- Failure artifacts: none"
assert_contains "$MARKDOWN_LOG" "ALL EXTERNAL MAIN MARKDOWN TESTS PASSED (txt)"
assert_contains "$RAG_LOG" "ALL EXTERNAL MAIN RAG TESTS PASSED (txt) (1 samples, 0 failures)"
assert_contains "$ASSETS_LOG" "ALL EXTERNAL MAIN ASSETS TESTS PASSED (0 samples, 0 failures)"
assert_not_exists "$ROOT/$RUN_DIR/reports/failures.md"

DIFF_RUN_DIR_REL="test-diff-$$"
DIFF_RUN_DIR="$ROOT/.tmp/tests/check/runs/$DIFF_RUN_DIR_REL"
WRAPPER="$OUT_DIR/fail-on-txt-wrapper.sh"
cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
REAL="$ROOT/_build/native/debug/build/cli/cli.exe"
if [[ "\${1-}" == "normal" && "\${2-}" == *"txt_plain.txt" ]]; then
  out_path="\${3-}"
  mkdir -p "\$(dirname "\$out_path")"
  printf '# forced diff mismatch\n' >"\$out_path"
  exit 0
fi
exec "\$REAL" "\$@"
EOF
chmod +x "$WRAPPER"

set +e
(
  cd "$ROOT"
  MARKITDOWN_CHECK_TMP_ROOT="$ROOT/.tmp/tests/check" \
  MARKITDOWN_TMP_DIR="$ROOT/.tmp/tests/check" \
  MARKITDOWN_CLI="$WRAPPER" \
  MARKITDOWN_QUALITY_LAB="$LAB_ROOT" \
  CHECK_RUN_ID="$DIFF_RUN_DIR_REL" \
  ./samples/check.sh --format txt
) >"$DIFF_LOG" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "forced diff mismatch samples/check.sh run should fail"

DIFF_SUMMARY_MD="$DIFF_RUN_DIR/summary.md"
DIFF_FAILURE_INDEX="$DIFF_RUN_DIR/reports/failures.md"
DIFF_REPORT="$DIFF_RUN_DIR/reports/failures/external_main_markdown_txt_txt_markdown_txt_plain.md"
DIFF_FILE="$DIFF_RUN_DIR/diff/external_main_markdown_txt_txt_markdown_txt_plain.diff"
DIFF_ACTUAL="$DIFF_RUN_DIR/raw/failures/external_main_markdown_txt_txt_markdown_txt_plain/actual.out"
DIFF_EXPECTED="$DIFF_RUN_DIR/raw/failures/external_main_markdown_txt_txt_markdown_txt_plain/expected.out"

[[ -f "$DIFF_SUMMARY_MD" ]] || fail "missing diff failure summary.md"
[[ -f "$DIFF_FAILURE_INDEX" ]] || fail "missing diff failure index"
[[ -f "$DIFF_REPORT" ]] || fail "missing diff per-sample failure report"
[[ -f "$DIFF_FILE" ]] || fail "missing diff artifact"
[[ -f "$DIFF_ACTUAL" ]] || fail "missing diff actual markdown"
[[ -f "$DIFF_EXPECTED" ]] || fail "missing diff expected markdown"
assert_contains "$DIFF_LOG" "result: fail"
assert_contains "$DIFF_SUMMARY_MD" "- Failure index:"
assert_contains "$DIFF_SUMMARY_MD" "- Failed diffs:"
assert_contains "$DIFF_FAILURE_INDEX" "external_main_markdown_txt_txt_markdown_txt_plain"
assert_contains "$DIFF_REPORT" "diff_mismatch"

FAIL_RUN_DIR_REL="test-failure-$$"
FAIL_RUN_DIR="$ROOT/.tmp/tests/check/runs/$FAIL_RUN_DIR_REL"
WRAPPER="$OUT_DIR/fail-on-txt-conversion-wrapper.sh"
cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
REAL="$ROOT/_build/native/debug/build/cli/cli.exe"
if [[ "\${1-}" == "normal" && "\${2-}" == *"txt_plain.txt" ]]; then
  printf 'forced contract failure for txt_plain\n' >&2
  exit 1
fi
exec "\$REAL" "\$@"
EOF
chmod +x "$WRAPPER"

set +e
(
  cd "$ROOT"
  MARKITDOWN_CHECK_TMP_ROOT="$ROOT/.tmp/tests/check" \
  MARKITDOWN_TMP_DIR="$ROOT/.tmp/tests/check" \
  MARKITDOWN_CLI="$WRAPPER" \
  MARKITDOWN_QUALITY_LAB="$LAB_ROOT" \
  CHECK_RUN_ID="$FAIL_RUN_DIR_REL" \
  ./samples/check.sh --format txt
) >"$FAIL_LOG" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "forced failing samples/check.sh run should fail"

FAIL_SUMMARY_MD="$FAIL_RUN_DIR/summary.md"
FAIL_FAILURE_INDEX="$FAIL_RUN_DIR/reports/failures.md"
FAIL_REPORT="$FAIL_RUN_DIR/reports/failures/external_main_markdown_txt_txt_markdown_txt_plain.md"
FAIL_STDERR="$FAIL_RUN_DIR/raw/failures/external_main_markdown_txt_txt_markdown_txt_plain/stderr.log"

[[ -f "$FAIL_SUMMARY_MD" ]] || fail "missing failure summary.md"
[[ -f "$FAIL_FAILURE_INDEX" ]] || fail "missing failure index"
[[ -f "$FAIL_REPORT" ]] || fail "missing per-sample failure report"
[[ -f "$FAIL_STDERR" ]] || fail "missing failure stderr log"
assert_contains "$FAIL_SUMMARY_MD" "- Failure index:"
assert_contains "$FAIL_SUMMARY_MD" "- Failed raw output:"
assert_contains "$FAIL_FAILURE_INDEX" "external_main_markdown_txt_txt_markdown_txt_plain"
assert_contains "$FAIL_REPORT" "conversion_failed"
assert_contains "$FAIL_STDERR" "forced contract failure"

set +e
(
  cd "$ROOT"
  MARKITDOWN_CHECK_TMP_ROOT="$ROOT/.tmp/tests/check" \
  MARKITDOWN_TMP_DIR="$ROOT/.tmp/tests/check" \
  MARKITDOWN_CLI="$OUT_DIR/missing-cli" \
  MARKITDOWN_QUALITY_LAB="$LAB_ROOT" \
  ./samples/check.sh --format txt
) >"$MISSING_LOG" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "missing native runner should fail"
assert_contains "$MISSING_LOG" "MARKITDOWN_CLI is set but not executable"

echo "SAMPLES CHECK CONTRACT PASSED"
