#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUALITY_CHECK="$ROOT/samples/helpers/quality/check.sh"
QUALITY_LAB_ROOT="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"
QUALITY_CORPUS_ROOT="$QUALITY_LAB_ROOT/external_quality"
QUALITY_MANIFEST_PATH="$QUALITY_CORPUS_ROOT/MANIFEST.tsv"
QUALITY_TMP_ROOT="${QUALITY_TMP_ROOT:-$ROOT/.tmp/quality}"
declare -a ORIGINAL_ARGS=()
if [[ $# -gt 0 ]]; then
  ORIGINAL_ARGS=("$@")
fi

usage() {
  cat <<'EOF'
Usage: ./samples/check_quality.sh [--format FORMAT] [--help]

Run the external quality validation entrypoint.

Default behavior:
  * runs only the external quality corpus from markitdown-quality-lab
  * expects:
      markitdown-quality-lab/external_quality/
      markitdown-quality-lab/external_quality/MANIFEST.tsv
  * does not fall back to repo-local quality rows
  * auto-detects whether the current main CLI supports `--with-metadata`
    and falls back to metadata-off when the option is still fail-closed
  * keeps raw per-row outputs for executed rows under `raw/`
  * writes non-pass per-row reports under `reports/`
  * uses `workspace/` only as scratch CLI temp space

Examples:
  ./samples/check_quality.sh
  ./samples/check_quality.sh --format pdf

If the external quality corpus is not present, clone it with:
  git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
EOF
}

display_path() {
  local path="$1"
  if [[ "$path" == "$ROOT" ]]; then
    printf '.'
  elif [[ "$path" == "$ROOT/"* ]]; then
    printf '%s' "${path#$ROOT/}"
  else
    printf '%s' "$path"
  fi
}

command_text() {
  printf './samples/check_quality.sh'
  local arg
  if ((${#ORIGINAL_ARGS[@]} > 0)); then
    for arg in "${ORIGINAL_ARGS[@]}"; do
      printf ' %q' "$arg"
    done
  fi
}

print_missing_corpus() {
  local missing_path="$1"
  echo "EXTERNAL QUALITY CORPUS NOT FOUND" >&2
  echo >&2
  echo "* expected: $(display_path "$QUALITY_CORPUS_ROOT")/" >&2
  echo "* missing: $(display_path "$missing_path")" >&2
  echo "* clone/place markitdown-quality-lab in the repo root" >&2
  echo "* clone: git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab" >&2
  echo "* local-only validation: bash samples/check.sh" >&2
}

summary_value_col() {
  local label="$1"
  local summary_path="$2"
  local column="$3"
  python3 - "$label" "$summary_path" "$column" <<'PY'
import csv
import sys

label, path, column_raw = sys.argv[1:]
column = int(column_raw)
with open(path, newline="", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter="\t")
    next(reader, None)
    for row in reader:
        if row and row[0] == label:
            value = row[column] if len(row) > column else ""
            print(value if value else "0")
            break
    else:
        print("0")
PY
}

summary_value() {
  summary_value_col "$1" "$2" 5
}

summary_total_value() {
  summary_value_col "$1" "$2" 6
}

summary_note_value() {
  summary_value_col "$1" "$2" 7
}

runner_from_log() {
  local log_path="$1"
  if grep -q "runner: built" "$log_path" 2>/dev/null; then
    printf 'built'
  elif grep -q "runner: prebuilt" "$log_path" 2>/dev/null; then
    printf 'prebuilt'
  elif grep -q "runner: moon-run" "$log_path" 2>/dev/null; then
    printf 'moon-run'
  else
    printf 'none'
  fi
}

FILTER_FORMAT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      [[ $# -ge 2 ]] || {
        echo "missing value for --format" >&2
        usage >&2
        exit 1
      }
      FILTER_FORMAT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_LABEL="all"
if [[ -n "$FILTER_FORMAT" ]]; then
  RUN_LABEL="$FILTER_FORMAT"
fi
QUALITY_RUN_ID="${QUALITY_RUN_ID:-${RUN_LABEL}-${RUN_STAMP}-$$}"
QUALITY_TMP_DIR="${QUALITY_TMP_DIR:-$QUALITY_TMP_ROOT/runs/$QUALITY_RUN_ID}"
LOG_DIR="$QUALITY_TMP_DIR/logs"
DIFF_DIR="$QUALITY_TMP_DIR/diff"
WORKSPACE_DIR="$QUALITY_TMP_DIR/workspace"
RAW_DIR="$QUALITY_TMP_DIR/raw"
REPORTS_DIR="$QUALITY_TMP_DIR/reports"
QUALITY_CLI_TMP_DIR="${QUALITY_CLI_TMP_DIR:-$WORKSPACE_DIR}"
SUMMARY_PATH="$QUALITY_TMP_DIR/summary.tsv"
SUMMARY_MD_PATH="$QUALITY_TMP_DIR/summary.md"
RUN_LOG_PATH="$LOG_DIR/entrypoint.log"

if [[ ! -d "$QUALITY_LAB_ROOT" ]]; then
  print_missing_corpus "$QUALITY_LAB_ROOT"
  exit 1
fi

if [[ ! -d "$QUALITY_CORPUS_ROOT" ]]; then
  print_missing_corpus "$QUALITY_CORPUS_ROOT"
  exit 1
fi

if [[ ! -f "$QUALITY_MANIFEST_PATH" ]]; then
  print_missing_corpus "$QUALITY_MANIFEST_PATH"
  exit 1
fi

declare -a runner_args=(
  --require-lab
  --corpus-root "$QUALITY_CORPUS_ROOT"
  --lab-manifest "$QUALITY_MANIFEST_PATH"
)
if [[ -n "$FILTER_FORMAT" ]]; then
  runner_args+=(--format "$FILTER_FORMAT")
fi

mkdir -p "$LOG_DIR" "$DIFF_DIR" "$WORKSPACE_DIR" "$RAW_DIR" "$REPORTS_DIR"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_SECONDS="$(date +%s)"

set +e
env \
  QUALITY_RUN_ID="$QUALITY_RUN_ID" \
  QUALITY_TMP_ROOT="$QUALITY_TMP_ROOT" \
  QUALITY_TMP_DIR="$QUALITY_TMP_DIR" \
  MARKITDOWN_CLI_TMP_DIR="$QUALITY_CLI_TMP_DIR" \
  MARKITDOWN_QUALITY_LAB="$QUALITY_LAB_ROOT" \
  MARKITDOWN_PROGRESS_FD=3 \
  bash "$QUALITY_CHECK" "${runner_args[@]}" 3>&1 >"$RUN_LOG_PATH" 2>&1
status=$?
set -e

rows="0"
checked="0"
failed="0"
skipped="0"
expected_fail="0"
selected_rows="0"
executable_rows="0"
artifact_groups="0"
skip_no_signals="0"
if [[ -f "$SUMMARY_PATH" ]]; then
  rows="$(summary_total_value "TOTAL" "$SUMMARY_PATH")"
  failed="$(summary_value "FAILED" "$SUMMARY_PATH")"
  skipped="$(summary_value "SKIPPED" "$SUMMARY_PATH")"
  expected_fail="$(summary_value "EXPECTED_FAIL" "$SUMMARY_PATH")"
  selected_rows="$(summary_note_value "SELECTED_ROWS" "$SUMMARY_PATH")"
  executable_rows="$(summary_note_value "EXECUTABLE_ROWS" "$SUMMARY_PATH")"
  artifact_groups="$(summary_note_value "ARTIFACT_GROUPS" "$SUMMARY_PATH")"
  skip_no_signals="$(summary_value "SKIPPED_NO_SIGNALS" "$SUMMARY_PATH")"
fi
if [[ "$rows" =~ ^[0-9]+$ && "$skipped" =~ ^[0-9]+$ && "$rows" -ge "$skipped" ]]; then
  checked=$((rows - skipped))
fi
runner_label="$(runner_from_log "$RUN_LOG_PATH")"

format_label="all"
if [[ -n "$FILTER_FORMAT" ]]; then
  format_label="$FILTER_FORMAT"
fi

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FINISH_SECONDS="$(date +%s)"
DURATION_SECONDS=$((FINISH_SECONDS - START_SECONDS))
result_label="pass"
result_word="PASS"
if [[ "$status" -ne 0 ]]; then
  result_label="fail"
  result_word="FAIL"
fi

{
  echo "# Run summary"
  echo
  echo "Status: $result_word"
  echo "Command: $(command_text)"
  echo "Run directory: $(display_path "$QUALITY_TMP_DIR")"
  echo "Manifest: $(display_path "$QUALITY_MANIFEST_PATH")"
  echo "Runner: $runner_label"
  echo "Started: $STARTED_AT"
  echo "Finished: $FINISHED_AT"
  echo "Duration: ${DURATION_SECONDS}s"
  echo
  echo "## What was checked"
  echo
  echo "External quality rows from markitdown-quality-lab. These rows are an external signal and no repo-local quality corpus fallback is used."
  echo
  echo "## Result"
  echo
  echo "- Formats: $format_label"
  echo "- Rows: $rows"
  echo "- Selected rows: $selected_rows"
  echo "- Executable rows: $executable_rows"
  echo "- Artifact groups: $artifact_groups"
  echo "- Checked: $checked"
  echo "- Skipped: $skipped"
  echo "- Skip no signals: $skip_no_signals"
  echo "- Failed: $failed"
  echo "- Expected fail: $expected_fail"
  echo
  echo "## Where to look next"
  echo
  echo "- Full log: $(display_path "$RUN_LOG_PATH")"
  echo "- Raw executed outputs: $(display_path "$RAW_DIR")"
  echo "- Non-pass index: $(display_path "$REPORTS_DIR/nonpass.md")"
  echo "- Row reports: $(display_path "$REPORTS_DIR/rows")"
  echo "- Workspace scratch: $(display_path "$WORKSPACE_DIR")"
} > "$SUMMARY_MD_PATH"

if [[ "$status" -ne 0 ]]; then
  echo "quality: format=$format_label manifest=$(display_path "$QUALITY_MANIFEST_PATH") runner=$runner_label"
  echo "run: $(display_path "$QUALITY_TMP_DIR")"
  echo "result: fail  rows=$rows checked=$checked skipped=$skipped failed=$failed"
  echo "summary: $(display_path "$SUMMARY_MD_PATH")"
  echo "details: $(display_path "$QUALITY_TMP_DIR")"
  echo "log: $(display_path "$RUN_LOG_PATH")"
  exit "$status"
fi

echo "quality: format=$format_label manifest=$(display_path "$QUALITY_MANIFEST_PATH") runner=$runner_label"
echo "run: $(display_path "$QUALITY_TMP_DIR")"
if [[ -n "$FILTER_FORMAT" && "$rows" == "0" ]]; then
  echo "note: no fallback; no repo-local samples were used"
fi
echo "result: $result_label  rows=$rows checked=$checked skipped=$skipped failed=$failed"
echo "summary: $(display_path "$SUMMARY_MD_PATH")"
echo "details: $(display_path "$QUALITY_TMP_DIR")"
