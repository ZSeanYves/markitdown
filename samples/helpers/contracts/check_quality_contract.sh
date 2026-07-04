#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/check}"
OUT_DIR="$(mktemp -d "$TMP_ROOT/quality_contract.XXXXXX")"

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

LAB_ROOT="$OUT_DIR/markitdown-quality-lab"
QUALITY_ROOT="$LAB_ROOT/external_quality"
mkdir -p "$QUALITY_ROOT/shared"
printf 'Alpha\nBeta\n' > "$QUALITY_ROOT/shared/shared.txt"

MANIFEST="$QUALITY_ROOT/MANIFEST.tsv"
cat >"$MANIFEST" <<'EOF'
id	format	path	source_type	source_id	license_status	license_review_status	privacy	size_class	features	expected_signals	quality_tier	original_url	local_cache_path	notes
txt_basic_quality	txt	external_quality/shared/shared.txt	file	contract_source	Apache-2.0	approved	public	small	txt;contract	no_empty_output;contains_all:Alpha|Beta;order:Alpha|Beta	gate			offline quality contract sample
txt_known_bad_quality	txt	external_quality/shared/shared.txt	file	contract_source	Apache-2.0	approved	public	small	txt;known_bad	contains:Gamma	known_bad			offline known-bad quality row
EOF

RUN_LOG="$OUT_DIR/run.log"

(
  cd "$ROOT"
  QUALITY_RUN_ID="contract-quality-$$" \
  MARKITDOWN_QUALITY_LAB="$LAB_ROOT" \
  ./samples/check_quality.sh --format txt
) >"$RUN_LOG" 2>&1

assert_contains "$RUN_LOG" "result: pass"

RUN_DIR="$(sed -n 's/^run: //p' "$RUN_LOG" | tail -1)"
[[ -n "$RUN_DIR" ]] || fail "missing quality run directory in output"

SUMMARY_MD="$ROOT/$RUN_DIR/summary.md"
NONPASS_MD="$ROOT/$RUN_DIR/reports/nonpass.md"
RAW_OUTPUTS_DIR="$ROOT/$RUN_DIR/raw/outputs"
ROW_REPORTS_DIR="$ROOT/$RUN_DIR/reports/rows"

[[ -f "$SUMMARY_MD" ]] || fail "missing quality summary.md"
[[ -f "$NONPASS_MD" ]] || fail "missing nonpass index"
[[ -d "$RAW_OUTPUTS_DIR" ]] || fail "missing raw outputs dir"
[[ -d "$ROW_REPORTS_DIR" ]] || fail "missing row reports dir"

assert_contains "$SUMMARY_MD" "- Raw executed outputs:"
assert_contains "$SUMMARY_MD" "- Non-pass index:"
assert_contains "$SUMMARY_MD" "- Row reports:"
assert_contains "$SUMMARY_MD" "- Workspace scratch:"
assert_contains "$NONPASS_MD" "# Non-pass Rows"
assert_contains "$NONPASS_MD" "expected_fail"
find "$ROW_REPORTS_DIR" -mindepth 1 -maxdepth 1 -type f -name '*.md' | grep -q . || fail "expected per-row non-pass reports"

find "$RAW_OUTPUTS_DIR" -mindepth 2 -type f -name '*.md' | grep -q . || fail "expected raw output markdown files"

echo "QUALITY CONTRACT PASSED"
