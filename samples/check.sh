#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLE_IMPL="$ROOT/samples/helpers/validation/check_samples_impl.sh"
CHECK_TMP_ROOT="${MARKITDOWN_CHECK_TMP_ROOT:-$ROOT/.tmp/check}"

ONLY_MODE=""
FORMAT_FILTER=""
declare -a ORIGINAL_ARGS=()
if [[ $# -gt 0 ]]; then
  ORIGINAL_ARGS=("$@")
fi

usage() {
  cat <<'EOF'
Usage: ./samples/check.sh [--markdown-only | --metadata-only | --assets-only] [--format FMT]

Runs repo-local samples/main_process regression checks.

Options:
  --markdown-only     Run only Markdown expected-output checks.
  --metadata-only     Run only metadata sidecar checks.
  --assets-only       Run only asset-reference checks.
  --format FMT        Restrict checks to one format, for example yaml.
  -h, --help          Show this help.

Default:
  Run markdown, metadata, and assets checks for all formats.
EOF
}

fail_usage() {
  echo "$1" >&2
  usage >&2
  exit 1
}

set_only_mode() {
  local mode="$1"
  if [[ -n "$ONLY_MODE" ]]; then
    fail_usage "choose at most one of --markdown-only, --metadata-only, --assets-only"
  fi
  ONLY_MODE="$mode"
}

deprecated_arg() {
  fail_usage "$1 is deprecated; supported options are --markdown-only, --metadata-only, --assets-only, and --format FMT"
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
  printf './samples/check.sh'
  local arg
  if ((${#ORIGINAL_ARGS[@]} > 0)); then
    for arg in "${ORIGINAL_ARGS[@]}"; do
      printf ' %q' "$arg"
    done
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown-only)
      set_only_mode "markdown-only"
      ;;
    --metadata-only)
      set_only_mode "metadata-only"
      ;;
    --assets-only)
      set_only_mode "assets-only"
      ;;
    --format)
      shift
      if [[ $# -eq 0 || "${1:-}" == --* ]]; then
        fail_usage "--format requires a value"
      fi
      FORMAT_FILTER="$1"
      ;;
    --full|--main-process|--contracts-only|--manifest-only)
      deprecated_arg "$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail_usage "unknown argument: $1"
      ;;
  esac
  shift
done

RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_LABEL="all"
if [[ -n "$FORMAT_FILTER" ]]; then
  RUN_LABEL="$FORMAT_FILTER"
fi
CHECK_RUN_ID="${CHECK_RUN_ID:-${RUN_LABEL}-${RUN_STAMP}-$$}"
CHECK_RUN_DIR="${CHECK_RUN_DIR:-$CHECK_TMP_ROOT/runs/$CHECK_RUN_ID}"
LOG_DIR="$CHECK_RUN_DIR/logs"
DIFF_DIR="$CHECK_RUN_DIR/diff"
WORKSPACE_DIR="$CHECK_RUN_DIR/workspace"
RAW_DIR="$CHECK_RUN_DIR/raw"
REPORTS_DIR="$CHECK_RUN_DIR/reports"
SUMMARY_PATH="$CHECK_RUN_DIR/summary.tsv"
SUMMARY_MD_PATH="$CHECK_RUN_DIR/summary.md"
ENTRYPOINT_LOG="$LOG_DIR/entrypoint.log"
mkdir -p "$LOG_DIR" "$DIFF_DIR" "$WORKSPACE_DIR" "$RAW_DIR" "$REPORTS_DIR"
: > "$ENTRYPOINT_LOG"
printf 'mode\tformat\tstatus\trunner\tchecks\tfailed\tlog_path\tnotes\n' > "$SUMMARY_PATH"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_SECONDS="$(date +%s)"
RUNNER_LABEL="none"
CHECKS_TOTAL=0
FAILED_TOTAL=0
SKIPPED_TOTAL=0

mode_display() {
  local mode="$1"
  printf '%s' "${mode%-only}"
}

format_display() {
  if [[ -n "$FORMAT_FILTER" ]]; then
    printf '%s' "$FORMAT_FILTER"
  else
    printf 'all'
  fi
}

update_runner_label() {
  local candidate="$1"
  case "$candidate" in
    built)
      RUNNER_LABEL="built"
      ;;
    prebuilt)
      if [[ "$RUNNER_LABEL" != "built" ]]; then
        RUNNER_LABEL="prebuilt"
      fi
      ;;
    moon-run)
      if [[ "$RUNNER_LABEL" == "none" ]]; then
        RUNNER_LABEL="moon-run"
      fi
      ;;
  esac
}

runner_from_log() {
  local log_path="$1"
  if grep -q "runner-note: built native" "$log_path" 2>/dev/null; then
    printf 'built'
  elif grep -q "runner: prebuilt-native\\|runner: override" "$log_path" 2>/dev/null; then
    printf 'prebuilt'
  elif grep -q "runner: moon-run" "$log_path" 2>/dev/null; then
    printf 'moon-run'
  else
    printf 'none'
  fi
}

checks_from_log() {
  local log_path="$1"
  sed -n 's/.*(\([0-9][0-9]*\) samples, \([0-9][0-9]*\) failures).*/\1/p' "$log_path" | tail -1
}

failures_from_log() {
  local log_path="$1"
  sed -n 's/.*(\([0-9][0-9]*\) samples, \([0-9][0-9]*\) failures).*/\2/p' "$log_path" | tail -1
}

run_impl() {
  local mode="$1"
  local args=("--$mode")
  local mode_short
  mode_short="$(mode_display "$mode")"
  local log_path="$LOG_DIR/$mode.entrypoint.log"
  local mode_workspace="$WORKSPACE_DIR/$mode"
  local fmt
  fmt="$(format_display)"
  if [[ -n "$FORMAT_FILTER" ]]; then
    args+=(--format "$FORMAT_FILTER")
  fi

  {
    echo "mode: $mode_short"
    echo "format: $fmt"
    echo "log: $(display_path "$log_path")"
  } >> "$ENTRYPOINT_LOG"

  set +e
  env \
    CHECK_SAMPLES_OUT_DIR="$mode_workspace/samples" \
    MARKITDOWN_CLI_TMP_DIR="$mode_workspace/cli" \
    SAMPLES_KEEP_TMP=1 \
    MARKITDOWN_PROGRESS_FD=3 \
    "$SAMPLE_IMPL" "${args[@]}" 3>&1 >"$log_path" 2>&1
  local status=$?
  set -e

  local runner checks failures line_status notes
  runner="$(runner_from_log "$log_path")"
  update_runner_label "$runner"
  checks="$(checks_from_log "$log_path")"
  failures="$(failures_from_log "$log_path")"
  checks="${checks:-0}"
  failures="${failures:-0}"
  CHECKS_TOTAL=$((CHECKS_TOTAL + checks))
  FAILED_TOTAL=$((FAILED_TOTAL + failures))

  if [[ "$status" -ne 0 ]]; then
    line_status="fail"
    notes="exit=$status"
  elif grep -q "No asset regression coverage" "$log_path" 2>/dev/null; then
    line_status="skip"
    notes="no asset regression coverage"
    SKIPPED_TOTAL=$((SKIPPED_TOTAL + 1))
  else
    line_status="pass"
    notes="markdown=$([[ "$mode_short" == "markdown" ]] && printf '%s' "$checks" || printf '0') metadata=$([[ "$mode_short" == "metadata" ]] && printf '%s' "$checks" || printf '0') assets=$([[ "$mode_short" == "assets" ]] && printf '%s' "$checks" || printf '0')"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$mode_short" "$fmt" "$line_status" "$runner" "$checks" "$failures" "$(display_path "$log_path")" "$notes" >> "$SUMMARY_PATH"
  cat "$log_path" >> "$ENTRYPOINT_LOG"
  return "$status"
}

write_summary_md() {
  local status="$1"
  local finished_at="$2"
  local duration="$3"
  local result_word="PASS"
  [[ "$status" -eq 0 ]] || result_word="FAIL"
  {
    echo "# Run summary"
    echo
    echo "Status: $result_word"
    echo "Command: $(command_text)"
    echo "Run directory: $(display_path "$CHECK_RUN_DIR")"
    echo "Runner: $RUNNER_LABEL"
    echo "Started: $STARTED_AT"
    echo "Finished: $finished_at"
    echo "Duration: ${duration}s"
    echo
    echo "## What was checked"
    echo
    echo "Repo-local samples/main_process checks for Markdown expectations, metadata sidecars, and asset references. Output details are kept in run logs and workspace files."
    echo
    echo "## Result"
    echo
    echo "- Formats: $(format_display)"
    echo "- Rows: $CHECKS_TOTAL"
    echo "- Checked: $CHECKS_TOTAL"
    echo "- Skipped: $SKIPPED_TOTAL"
    echo "- Failed: $FAILED_TOTAL"
    echo
    echo "## Where to look next"
    echo
    echo "- Full log: $(display_path "$ENTRYPOINT_LOG")"
    echo "- Diffs: $(display_path "$DIFF_DIR")"
    echo "- Raw output: $(display_path "$RAW_DIR")"
    echo "- Reports: $(display_path "$REPORTS_DIR")"
  } > "$SUMMARY_MD_PATH"
}

print_result() {
  local status="$1"
  local result_label="pass"
  [[ "$status" -eq 0 ]] || result_label="fail"
  local format_status="$result_label"
  if [[ "$status" -eq 0 && "$CHECKS_TOTAL" -eq 0 && "$SKIPPED_TOTAL" -gt 0 ]]; then
    format_status="skip"
  fi
  echo "check: format=$(format_display) mode=$([[ -n "$ONLY_MODE" ]] && mode_display "$ONLY_MODE" || printf 'all') runner=$RUNNER_LABEL"
  echo "run: $(display_path "$CHECK_RUN_DIR")"
  echo "result: $result_label  formats=$(format_display) rows=$CHECKS_TOTAL checked=$CHECKS_TOTAL skipped=$SKIPPED_TOTAL failed=$FAILED_TOTAL"
  echo "summary: $(display_path "$SUMMARY_MD_PATH")"
  echo "details: $(display_path "$CHECK_RUN_DIR")"
}

overall_status=0
if [[ -n "$ONLY_MODE" ]]; then
  run_impl "$ONLY_MODE" || overall_status=$?
else
  run_impl "markdown-only" || overall_status=$?
  if [[ "$overall_status" -eq 0 ]]; then
    run_impl "metadata-only" || overall_status=$?
  fi
  if [[ "$overall_status" -eq 0 ]]; then
    run_impl "assets-only" || overall_status=$?
  fi
fi

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FINISH_SECONDS="$(date +%s)"
DURATION_SECONDS=$((FINISH_SECONDS - START_SECONDS))
write_summary_md "$overall_status" "$FINISHED_AT" "$DURATION_SECONDS"
print_result "$overall_status"

exit "$overall_status"
