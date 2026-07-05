#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp/tests/check}"
mkdir -p "$TMP_ROOT"
OUT_DIR="$(mktemp -d "$TMP_ROOT/quality_grouping_contract.XXXXXX")"

trap 'status=$?; if [[ "$status" -ne 0 ]]; then echo "[debug] preserved: $OUT_DIR" >&2; else rm -rf "$OUT_DIR"; fi; exit "$status"' EXIT

fail() {
  echo "[fail] $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected $path to contain: $needle"
}

QUALITY_ROOT="$OUT_DIR/external_quality"
mkdir -p "$QUALITY_ROOT/shared"
printf 'shared input\n' > "$QUALITY_ROOT/shared/shared.txt"
printf 'fail input\n' > "$QUALITY_ROOT/shared/fail.txt"
printf 'pngish\n' > "$QUALITY_ROOT/shared/shared.png"
printf 'msgish\n' > "$QUALITY_ROOT/shared/shared.msg"

MANIFEST="$QUALITY_ROOT/MANIFEST.tsv"
cat >"$MANIFEST" <<'EOF'
id	format	path	source_type	source_id	license_status	license_review_status	privacy	size_class	features	expected_signals	quality_tier	original_url	local_cache_path	notes
blank_row	txt	external_quality/shared/shared.txt	file	contract_source	ok	approved	public	small	test		gate			blank row
dup_row_a	txt	external_quality/shared/shared.txt	file	contract_source	ok	approved	public	small	test	contains:Alpha;exact_count:Alpha=1	gate			first duplicate row
dup_row_b	txt	external_quality/shared/shared.txt	file	contract_source	ok	approved	public	small	test	order:Alpha|Beta	reference			second duplicate row
accurate_row	txt	external_quality/shared/shared.txt	file	contract_source	ok	approved	public	small	test;accurate	contains:Alpha	gate			accurate flag row
fail_row	txt	external_quality/shared/fail.txt	file	contract_source	ok	approved	public	small	test	contains:ignored	gate			shared failure row
fail_known_bad	txt	external_quality/shared/fail.txt	file	contract_source	ok	approved	public	small	test	contains:ignored	known_bad			shared failure known bad
ocr_row	ocr	external_quality/shared/shared.png	file	contract_source	ok	approved	public	small	test	contains:Alpha	gate			ocr pseudo-format row
eml_row	eml	external_quality/shared/shared.msg	file	contract_source	ok	approved	public	small	test	contains:Alpha	gate			eml alias row
EOF

STUB_LOG="$OUT_DIR/stub.log"
STUB_CLI="$OUT_DIR/stub_cli.sh"
cat >"$STUB_CLI" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"__STUB_LOG__"
mode="${1-}"
shift || true
if [[ "$mode" == "--help" ]]; then
  cat <<'HELP'
Supported product formats: txt, csv, tsv, json, jsonl, ndjson, xml
`--accurate` upgrades fidelity while preserving the selected output mode.
HELP
  exit 0
fi
if [[ "$mode" == "normal" ]]; then
  while [[ $# -gt 0 ]]; do
    case "${1-}" in
      --accurate)
        shift
        ;;
      --format)
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done
fi
input="${1-}"
output="${2-}"
mkdir -p "$(dirname "$output")"
if [[ "$input" == *"fail.txt" ]]; then
  printf 'stub forced failure\n' >&2
  exit 1
fi
printf 'Alpha\nBeta\n' >"$output"
exit 0
EOF
python3 - "$STUB_CLI" "$STUB_LOG" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
log_path = sys.argv[2]
path.write_text(path.read_text(encoding="utf-8").replace("__STUB_LOG__", log_path), encoding="utf-8")
PY
chmod +x "$STUB_CLI"

RUN_DIR_REL="test-quality-grouping-$$"
RUN_DIR="$ROOT/.tmp/tests/quality/runs/$RUN_DIR_REL"
RUN_LOG="$OUT_DIR/run.log"

set +e
(
  cd "$ROOT"
  MARKITDOWN_CLI="$STUB_CLI" \
  QUALITY_RUN_ID="$RUN_DIR_REL" \
  QUALITY_TMP_ROOT="$ROOT/.tmp/tests/quality" \
  MARKITDOWN_TMP_DIR="$ROOT/.tmp/tests/quality" \
  MARKITDOWN_QUALITY_LAB="$OUT_DIR" \
  bash samples/helpers/quality/check.sh \
    --require-lab \
    --corpus-root "$QUALITY_ROOT" \
    --lab-manifest "$MANIFEST"
) >"$RUN_LOG" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "expected mixed fail/expected_fail grouping run to exit non-zero"

SUMMARY_TSV="$RUN_DIR/summary.tsv"
SUMMARY_MD="$RUN_DIR/summary.md"
ROWS_TSV="$RUN_DIR/rows.tsv"
ROW_REPORTS="$RUN_DIR/reports/rows"
NONPASS_MD="$RUN_DIR/reports/nonpass.md"

[[ -f "$SUMMARY_TSV" ]] || fail "missing summary.tsv"
[[ -f "$SUMMARY_MD" ]] || fail "missing summary.md"
[[ -f "$ROWS_TSV" ]] || fail "missing rows.tsv"
[[ -f "$NONPASS_MD" ]] || fail "missing nonpass.md"
[[ -d "$ROW_REPORTS" ]] || fail "missing row reports dir"

assert_contains "$RUN_LOG" "skip_no_signals: 1"
assert_contains "$RUN_LOG" "selected_rows: 8"
assert_contains "$RUN_LOG" "executable_rows: 7"
assert_contains "$RUN_LOG" "artifact_groups: 5"
assert_contains "$SUMMARY_TSV" $'blank_row\ttxt\texternal\tgate\tskip_no_signals\t0\t0\tno executable signals configured'
assert_contains "$SUMMARY_TSV" $'dup_row_a\ttxt\texternal\tgate\tpass\t2\t2\tall signals passed'
assert_contains "$SUMMARY_TSV" $'dup_row_b\ttxt\texternal\treference\tpass\t1\t1\tall signals passed'
assert_contains "$SUMMARY_TSV" $'accurate_row\ttxt\texternal\tgate\tpass\t1\t1\tall signals passed'
assert_contains "$SUMMARY_TSV" $'fail_row\ttxt\texternal\tgate\tfail\t0\t0\tcli conversion failed: stub forced failure'
assert_contains "$SUMMARY_TSV" $'fail_known_bad\ttxt\texternal\tknown_bad\texpected_fail\t0\t0\texpected converter failure: cli conversion failed: stub forced failure'
assert_contains "$SUMMARY_TSV" $'ocr_row\tocr\texternal\tgate\tpass\t1\t1\tall signals passed'
assert_contains "$SUMMARY_TSV" $'eml_row\teml\texternal\tgate\tpass\t1\t1\tall signals passed'
assert_contains "$SUMMARY_TSV" $'SKIPPED_NO_SIGNALS\t-\t-\t-\t-\t1\t-\tskipped because the row had no executable signals'
assert_contains "$SUMMARY_TSV" $'SELECTED_ROWS\t-\t-\t-\t-\t0\t0\t8'
assert_contains "$SUMMARY_TSV" $'EXECUTABLE_ROWS\t-\t-\t-\t-\t0\t0\t7'
assert_contains "$SUMMARY_TSV" $'ARTIFACT_GROUPS\t-\t-\t-\t-\t0\t0\t5'
assert_contains "$SUMMARY_MD" "- selected_rows: 8"
assert_contains "$SUMMARY_MD" "- executable_rows: 7"
assert_contains "$SUMMARY_MD" "- artifact_groups: 5"
assert_contains "$SUMMARY_MD" "- skip_no_signals: 1"
assert_contains "$NONPASS_MD" "fail_row"
assert_contains "$NONPASS_MD" "fail_known_bad"
[[ ! -f "$ROW_REPORTS/blank_row.md" ]] || fail "blank row should not generate row report"
[[ -f "$ROW_REPORTS/fail_row.md" ]] || fail "expected fail_row report"
[[ -f "$ROW_REPORTS/fail_known_bad.md" ]] || fail "expected fail_known_bad report"

call_count="$(wc -l < "$STUB_LOG" | tr -d '[:space:]')"
[[ "$call_count" == "5" ]] || fail "expected 5 stub invocations (artifact groups only), got $call_count"
grep -F -- '--accurate' "$STUB_LOG" >/dev/null || fail "expected one grouped conversion to include --accurate"
if grep -F -- '--format ocr' "$STUB_LOG" >/dev/null; then
  fail "ocr pseudo-format row must not pass unsupported --format ocr to the CLI"
fi
grep -F -- '--format eml' "$STUB_LOG" >/dev/null || fail "expected eml alias row to pass --format eml"
grep -F -- '--format png' "$STUB_LOG" >/dev/null || fail "expected ocr pseudo-format row to pass an image format"

shared_artifact_md_count="$(find "$RUN_DIR/raw/outputs" -mindepth 2 -type f -name 'result.md' | wc -l | tr -d '[:space:]')"
[[ "$shared_artifact_md_count" == "4" ]] || fail "expected exactly four successful shared artifact markdown files (balanced + accurate + ocr artifact + eml alias artifact), got $shared_artifact_md_count"

echo "QUALITY GROUPING CONTRACT PASSED"
