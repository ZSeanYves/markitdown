#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLE_IMPL="$ROOT/samples/helpers/validation/check_samples_impl.sh"
CHECK_TMP_ROOT="${MARKITDOWN_CHECK_TMP_ROOT:-$ROOT/.tmp/check}"
SUPPORTED_FORMATS=("txt" "csv" "tsv" "json" "jsonl" "ndjson" "xml" "yaml" "html" "markdown" "zip" "epub" "docx" "xlsx" "pptx" "pdf")

ONLY_MODE=""
FORMAT_FILTER=""
SPECIAL_MODE=""
declare -a ORIGINAL_ARGS=()
if [[ $# -gt 0 ]]; then
  ORIGINAL_ARGS=("$@")
fi

usage() {
  cat <<'EOF'
Usage: ./samples/check.sh [--markdown|--rag|--assets] [--format FMT] [--check-inventory] [--list-inventory]

Runs repo-local samples/main_process regression checks.

Options:
  --markdown          Run only Markdown expected-output checks.
  --rag               Run only RAG expected-output checks.
  --assets            Run only light-asset expected-output checks.
  --format FMT        Restrict checks to one supported product format: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, pdf.
  --check-inventory   Run sample enrollment/integrity checks without conversion.
  --list-inventory    Print sample inventory counts in TSV form.
  -h, --help          Show this help.

Default:
  Run markdown, rag, and assets checks for the main CLI gate: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, and pdf.
  Unsupported formats fail closed here.

Run artifacts:
  Only failure artifacts are retained under the run directory.
  `workspace/` is scratch-only and should not be used as the primary inspection surface.
EOF
}

fail_usage() {
  echo "$1" >&2
  usage >&2
  exit 1
}

set_only_mode() {
  if [[ -n "$ONLY_MODE" ]]; then
    fail_usage "choose only one of --markdown, --rag, or --assets"
  fi
  ONLY_MODE="$1"
}

set_special_mode() {
  if [[ -n "$SPECIAL_MODE" ]]; then
    fail_usage "choose only one of --check-inventory or --list-inventory"
  fi
  SPECIAL_MODE="$1"
}

deprecated_arg() {
  fail_usage "$1 is deprecated; supported options are --markdown, --rag, --assets, --format FMT, --check-inventory, and --list-inventory"
}

supported_formats_compact() {
  local IFS=","
  printf '%s' "${SUPPORTED_FORMATS[*]}"
}

supported_formats_display() {
  local IFS=", "
  printf '%s' "${SUPPORTED_FORMATS[*]}"
}

format_is_supported() {
  local target="$1"
  local fmt
  for fmt in "${SUPPORTED_FORMATS[@]}"; do
    if [[ "$fmt" == "$target" ]]; then
      return 0
    fi
  done
  return 1
}

fail_unsupported_format() {
  local format="$1"
  echo "unsupported format for the main CLI gate in this build: $format" >&2
  echo "supported gate formats: $(supported_formats_display)" >&2
  echo "unsupported formats fail closed; no alternate product route is available here" >&2
  exit 1
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
    --markdown)
      set_only_mode "markdown"
      ;;
    --rag)
      set_only_mode "rag"
      ;;
    --assets)
      set_only_mode "assets"
      ;;
    --format)
      shift
      if [[ $# -eq 0 || "${1:-}" == --* ]]; then
        fail_usage "--format requires a value"
      fi
      FORMAT_FILTER="$1"
      ;;
    --check-inventory)
      set_special_mode "check-inventory"
      ;;
    --list-inventory)
      set_special_mode "list-inventory"
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

if [[ -n "$SPECIAL_MODE" && -n "$ONLY_MODE" ]]; then
  fail_usage "--$ONLY_MODE cannot be combined with --$SPECIAL_MODE"
fi
if [[ -n "$SPECIAL_MODE" && -n "$FORMAT_FILTER" ]]; then
  fail_usage "--format cannot be combined with --$SPECIAL_MODE"
fi

if [[ -n "$FORMAT_FILTER" ]] && ! format_is_supported "$FORMAT_FILTER"; then
  fail_unsupported_format "$FORMAT_FILTER"
fi

if [[ "$SPECIAL_MODE" == "check-inventory" ]]; then
  "$SAMPLE_IMPL" --check-inventory
  exit 0
fi

if [[ "$SPECIAL_MODE" == "list-inventory" ]]; then
  "$SAMPLE_IMPL" --list-inventory
  exit 0
fi

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
FAILURE_REPORTS_DIR="$REPORTS_DIR/failures"
SUMMARY_PATH="$CHECK_RUN_DIR/summary.tsv"
SUMMARY_MD_PATH="$CHECK_RUN_DIR/summary.md"
ENTRYPOINT_LOG="$LOG_DIR/entrypoint.log"
mkdir -p "$LOG_DIR" "$DIFF_DIR" "$WORKSPACE_DIR" "$RAW_DIR/failures" "$FAILURE_REPORTS_DIR"
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
  printf '%s' "$mode"
}

format_display() {
  if [[ -n "$FORMAT_FILTER" ]]; then
    printf '%s' "$FORMAT_FILTER"
  else
    supported_formats_compact
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
  local parsed
  parsed="$(sed -n 's/.*(\([0-9][0-9]*\) samples, \([0-9][0-9]*\) failures).*/\1/p' "$log_path" | tail -1)"
  if [[ -n "$parsed" ]]; then
    printf '%s\n' "$parsed"
    return 0
  fi

  parsed="$(sed -n 's/.*(\([0-9][0-9]*\) failures).*/\1/p' "$log_path" | tail -1)"
  if [[ -n "$parsed" ]]; then
    printf '%s\n' "$parsed"
  fi
}

failures_from_log() {
  local log_path="$1"
  local parsed
  parsed="$(sed -n 's/.*(\([0-9][0-9]*\) samples, \([0-9][0-9]*\) failures).*/\2/p' "$log_path" | tail -1)"
  if [[ -n "$parsed" ]]; then
    printf '%s\n' "$parsed"
    return 0
  fi

  parsed="$(sed -n 's/.*(\([0-9][0-9]*\) failures).*/\1/p' "$log_path" | tail -1)"
  if [[ -n "$parsed" ]]; then
    printf '%s\n' "$parsed"
  fi
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
    CHECK_FAILURE_DIFF_DIR="$DIFF_DIR" \
    CHECK_FAILURE_RAW_DIR="$RAW_DIR/failures" \
    CHECK_FAILURE_REPORTS_DIR="$FAILURE_REPORTS_DIR" \
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
  else
    line_status="pass"
    notes="lane=$mode_short checks=$checks failures=$failures"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$mode_short" "$fmt" "$line_status" "$runner" "$checks" "$failures" "$(display_path "$log_path")" "$notes" >> "$SUMMARY_PATH"
  cat "$log_path" >> "$ENTRYPOINT_LOG"
  return "$status"
}

count_failure_reports() {
  if [[ ! -d "$FAILURE_REPORTS_DIR" ]]; then
    printf '0'
    return 0
  fi
  find "$FAILURE_REPORTS_DIR" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d '[:space:]'
}

write_failures_index() {
  local report_count
  report_count="$(count_failure_reports)"
  if [[ "$report_count" == "0" ]]; then
    rm -f "$REPORTS_DIR/failures.md"
    return 0
  fi
  local index_path="$REPORTS_DIR/failures.md"
  {
    echo "# Failure Index"
    echo
    echo "- Failure reports: $report_count"
    echo "- Diff directory: $(display_path "$DIFF_DIR")"
    echo "- Failure raw artifacts: $(display_path "$RAW_DIR/failures")"
    echo
    local report
    for report in $(find "$FAILURE_REPORTS_DIR" -maxdepth 1 -type f -name '*.md' | sort); do
      local name
      name="$(basename "$report" .md)"
      echo "- [$name]($(display_path "$report"))"
    done
  } > "$index_path"
}

write_summary_md() {
  local status="$1"
  local finished_at="$2"
  local duration="$3"
  local lanes="markdown, rag, assets"
  local result_word="PASS"
  local failure_report_count
  [[ "$status" -eq 0 ]] || result_word="FAIL"
  failure_report_count="$(count_failure_reports)"
  if [[ -n "$ONLY_MODE" ]]; then
    lanes="$ONLY_MODE"
  fi
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
    echo "Repo-local samples/main_process lane checks for the main CLI gate: txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, and pdf."
    echo "Lanes: $lanes"
    echo "Formats outside the current gate fail closed and are not part of this check."
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
    echo "- Workspace scratch: $(display_path "$WORKSPACE_DIR")"
    if [[ "$failure_report_count" == "0" ]]; then
      echo "- Failure artifacts: none"
    else
      echo "- Failure index: $(display_path "$REPORTS_DIR/failures.md")"
      echo "- Failed diffs: $(display_path "$DIFF_DIR")"
      echo "- Failed raw output: $(display_path "$RAW_DIR/failures")"
      echo "- Failed reports: $(display_path "$FAILURE_REPORTS_DIR")"
    fi
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
  run_impl "markdown" || overall_status=$?
  run_impl "rag" || overall_status=$?
  run_impl "assets" || overall_status=$?
fi

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FINISH_SECONDS="$(date +%s)"
DURATION_SECONDS=$((FINISH_SECONDS - START_SECONDS))
write_failures_index
write_summary_md "$overall_status" "$FINISHED_AT" "$DURATION_SECONDS"
print_result "$overall_status"

exit "$overall_status"
