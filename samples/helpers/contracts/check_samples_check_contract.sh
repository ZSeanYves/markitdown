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

(
  cd "$ROOT"
  MARKITDOWN_CLI="$ROOT/_build/native/debug/build/cli/cli.exe" \
  MARKITDOWN_PDF_CLI="$ROOT/_build/native/debug/build/pdf/pdf.exe" \
  MARKITDOWN_ZIP_CLI="$ROOT/_build/native/debug/build/zip/zip.exe" \
  ./samples/check.sh --format pdf
) >"$RUN_LOG" 2>&1 || true

assert_contains "$RUN_LOG" "runner=prebuilt"
assert_contains "$RUN_LOG" "rows=30"
assert_contains "$RUN_LOG" "failed=9"

RUN_DIR="$(sed -n 's/^run: //p' "$RUN_LOG" | tail -1)"
[[ -n "$RUN_DIR" ]] || fail "missing run directory in output"

SUMMARY_TSV="$ROOT/$RUN_DIR/summary.tsv"
SUMMARY_MD="$ROOT/$RUN_DIR/summary.md"
MARKDOWN_LOG="$ROOT/$RUN_DIR/logs/markdown-only.entrypoint.log"

[[ -f "$SUMMARY_TSV" ]] || fail "missing summary.tsv"
[[ -f "$SUMMARY_MD" ]] || fail "missing summary.md"
[[ -f "$MARKDOWN_LOG" ]] || fail "missing markdown-only entrypoint log"

assert_contains "$SUMMARY_TSV" $'markdown\tpdf\tfail\tprebuilt\t30\t9\t'
assert_contains "$SUMMARY_MD" "- Rows: 30"
assert_contains "$SUMMARY_MD" "- Failed: 9"
assert_contains "$MARKDOWN_LOG" "FAILED MAIN PROCESS MARKDOWN SAMPLES (pdf) (30 samples, 9 failures)"

echo "SAMPLES CHECK CONTRACT PASSED"
