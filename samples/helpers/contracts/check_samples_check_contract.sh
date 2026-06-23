#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(mktemp -d "$TMP_ROOT/check_contract.XXXXXX")"

trap 'status=$?; rm -rf "$OUT_DIR"; exit "$status"' EXIT

fail() {
  echo "[fail] $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

RUN_LOG="$OUT_DIR/run.log"
DOCX_LOG="$OUT_DIR/docx.log"
DEFAULT_LOG="$OUT_DIR/default.log"
MARKDOWN_LOG="$OUT_DIR/markdown.log"

(
  cd "$ROOT"
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  ./samples/check.sh --format txt
) >"$RUN_LOG" 2>&1

assert_contains "$RUN_LOG" "runner=prebuilt"
assert_contains "$RUN_LOG" "result: pass"
assert_contains "$RUN_LOG" "formats=txt"

RUN_DIR="$(sed -n 's/^run: //p' "$RUN_LOG" | tail -1)"
[[ -n "$RUN_DIR" ]] || fail "missing run directory in output"

SUMMARY_TSV="$ROOT/$RUN_DIR/summary.tsv"
SUMMARY_MD="$ROOT/$RUN_DIR/summary.md"
MARKDOWN_LOG="$ROOT/$RUN_DIR/logs/markdown-only.entrypoint.log"

[[ -f "$SUMMARY_TSV" ]] || fail "missing summary.tsv"
[[ -f "$SUMMARY_MD" ]] || fail "missing summary.md"
[[ -f "$MARKDOWN_LOG" ]] || fail "missing markdown-only entrypoint log"

assert_contains "$SUMMARY_TSV" $'markdown\ttxt\tpass\tprebuilt\t'
assert_contains "$SUMMARY_MD" "- Formats: txt"
assert_contains "$SUMMARY_MD" "- Failed: 0"
assert_contains "$MARKDOWN_LOG" "ALL MAIN PROCESS MARKDOWN TESTS PASSED (txt)"

(
  cd "$ROOT"
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  ./samples/check.sh
) >"$DEFAULT_LOG" 2>&1

assert_contains "$DEFAULT_LOG" "result: pass"
assert_contains "$DEFAULT_LOG" "formats=txt,csv,tsv,json,jsonl,ndjson,xml,yaml,html,markdown,zip,epub,docx,xlsx,pptx,pdf"
assert_contains "$DEFAULT_LOG" "check: format=txt,csv,tsv,json,jsonl,ndjson,xml,yaml,html,markdown,zip,epub,docx,xlsx,pptx,pdf"

(
  cd "$ROOT"
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  ./samples/check.sh --format docx
) >"$DOCX_LOG" 2>&1
assert_contains "$DOCX_LOG" "result: pass"
assert_contains "$DOCX_LOG" "formats=docx"

XLSX_LOG="$OUT_DIR/xlsx.log"
(
  cd "$ROOT"
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  ./samples/check.sh --format xlsx
) >"$XLSX_LOG" 2>&1
assert_contains "$XLSX_LOG" "result: pass"
assert_contains "$XLSX_LOG" "formats=xlsx"

PPTX_LOG="$OUT_DIR/pptx.log"
(
  cd "$ROOT"
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  ./samples/check.sh --format pptx
) >"$PPTX_LOG" 2>&1
assert_contains "$PPTX_LOG" "formats=pptx"

PDF_LOG="$OUT_DIR/pdf.log"
(
  cd "$ROOT"
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  ./samples/check.sh --format pdf
) >"$PDF_LOG" 2>&1
assert_contains "$PDF_LOG" "result: pass"
assert_contains "$PDF_LOG" "formats=pdf"

set +e
(
  cd "$ROOT"
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  ./samples/check.sh --format markdown
) >"$MARKDOWN_LOG" 2>&1
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "markdown samples check should pass"
assert_contains "$MARKDOWN_LOG" "result: pass"
assert_contains "$MARKDOWN_LOG" "formats=markdown"

echo "SAMPLES CHECK CONTRACT PASSED"
