#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLE_IMPL="$ROOT/samples/helpers/validation/check_samples_impl.sh"
source "$ROOT/samples/helpers/shared/cli_runner.sh"
source "$ROOT/samples/helpers/shared/regression_common.sh"
CHECK_TMP_ROOT="${MARKITDOWN_CHECK_TMP_ROOT:-$ROOT/.tmp/check}"
SUPPORTED_FORMATS=("txt" "csv" "tsv" "srt" "vtt" "json" "jsonl" "ndjson" "ipynb" "xml" "yaml" "toml" "html" "markdown" "eml" "tex" "rst" "asciidoc" "zip" "epub" "odt" "ods" "odp" "docx" "xlsx" "pptx" "pdf" "wav" "mp3" "m4a" "ocr")
BALANCE_AUDIO_RUNTIME_MODE="${MARKITDOWN_BALANCE_AUDIO_RUNTIME:-mock}"
BALANCE_AUDIO_MOCK_ACTIVE=0
BALANCE_AUDIO_RUNTIME_NOTE="environment"

ONLY_MODE=""
FORMAT_FILTER=""
SPECIAL_MODE=""
declare -a ORIGINAL_ARGS=()
if [[ $# -gt 0 ]]; then
  ORIGINAL_ARGS=("$@")
fi

audio_format_selected() {
  case "${1-}" in
    wav|mp3|m4a)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

balance_audio_mock_enabled() {
  local raw="${BALANCE_AUDIO_RUNTIME_MODE:-mock}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    real|0|false|off)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

balance_run_needs_audio_runtime() {
  if [[ -n "$FORMAT_FILTER" ]]; then
    audio_format_selected "$FORMAT_FILTER"
    return $?
  fi
  if [[ "$ONLY_MODE" == "assets" || "$ONLY_MODE" == "ocr" ]]; then
    return 1
  fi
  return 0
}

resolve_balance_audio_mock_python() {
  if [[ -n "${MARKITDOWN_RUNTIME_PYTHON:-}" && -x "${MARKITDOWN_RUNTIME_PYTHON}" ]]; then
    printf '%s' "$MARKITDOWN_RUNTIME_PYTHON"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
    return 0
  fi
  return 1
}

setup_balance_audio_mock_runtime() {
  if ! balance_audio_mock_enabled; then
    BALANCE_AUDIO_RUNTIME_NOTE="environment"
    return 0
  fi
  if ! balance_run_needs_audio_runtime; then
    BALANCE_AUDIO_RUNTIME_NOTE="not-needed"
    return 0
  fi

  local python_cmd ffmpeg_stub quoted_python quoted_ffmpeg quoted_wrapper
  python_cmd="$(resolve_balance_audio_mock_python)" || {
    echo "samples/check_balance.sh needs python3 or MARKITDOWN_RUNTIME_PYTHON for the deterministic audio mock backend" >&2
    return 1
  }
  ffmpeg_stub="$CHECK_RUN_DIR/audio-mock/bin/ffmpeg"
  mkdir -p "$(dirname "$ffmpeg_stub")"
  printf -v quoted_python '%q' "$python_cmd"
  printf -v quoted_ffmpeg '%q' "$ROOT/samples/helpers/mock_ffmpeg.py"
  printf -v quoted_wrapper '%q %q' "$python_cmd" "$ROOT/samples/helpers/mock_vosk_wrapper.py"
  cat >"$ffmpeg_stub" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec $quoted_python $quoted_ffmpeg "\$@"
EOF
  chmod +x "$ffmpeg_stub"
  # The repo-managed audio runtime now resolves relative to cwd. Keep audio
  # samples on an isolated cwd so the deterministic mock remains the active
  # wrapper during balance regression runs.
  mkdir -p "$CHECK_RUN_DIR/audio-mock/cwd"
  export PATH="$(dirname "$ffmpeg_stub"):$PATH"
  export MARKITDOWN_AUDIO_CMD="$quoted_wrapper"
  export MARKITDOWN_AUDIO_RUNNER_CWD="$CHECK_RUN_DIR/audio-mock/cwd"
  BALANCE_AUDIO_MOCK_ACTIVE=1
  BALANCE_AUDIO_RUNTIME_NOTE="deterministic-mock"
}

usage() {
  cat <<'EOF'
Usage: ./samples/check_balance.sh [--markdown|--rag|--assets|--ocr] [--format FMT|--formats FMT] [--check-inventory] [--list-inventory]

Runs the external main balance regression gate from ./markitdown-quality-lab/external_main_process.

Options:
  --markdown          Run only Markdown expected-output checks.
  --rag               Run only RAG expected-output checks.
  --assets            Run only light-asset expected-output checks.
  --ocr               Run only explicit OCR-lane expected-output checks.
  --format FMT        Restrict checks to one supported balance-gate format: txt, csv, tsv, srt, vtt, json, jsonl, ndjson, ipynb, xml, yaml, toml, html, markdown, eml, tex, rst, asciidoc, zip, epub, odt, ods, odp, docx, xlsx, pptx, pdf, wav, mp3, m4a, ocr.
  --formats FMT       Backward-compatible alias of --format for one format.
  --check-inventory   Run sample enrollment/integrity checks without conversion.
  --list-inventory    Print sample inventory counts in TSV form.
  -h, --help          Show this help.

Default:
  Run markdown, rag, assets, and explicit OCR-lane checks for the external main balance gate: txt, csv, tsv, srt, vtt, json, jsonl, ndjson, ipynb, xml, yaml, toml, html, markdown, eml, tex, rst, asciidoc, zip, epub, odt, ods, odp, docx, xlsx, pptx, pdf, wav, mp3, m4a, and ocr.
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
  echo "unsupported format for the balance CLI gate in this build: $format" >&2
  echo "supported gate formats: $(supported_formats_display)" >&2
  echo "unsupported formats fail closed; no alternate product route is available here" >&2
  exit 1
}

command_text() {
  printf './samples/check_balance.sh'
  append_command_args "${ORIGINAL_ARGS[@]}"
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
    --ocr)
      set_only_mode "ocr"
      ;;
    --format|--formats)
      shift
      if [[ $# -eq 0 || "${1:-}" == --* ]]; then
        fail_usage "$1 requires a value"
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

resolve_markitdown_cli
if [[ "${CLI_RUNNER_KIND:-}" == "prebuilt" || "${CLI_RUNNER_KIND:-}" == "override" ]]; then
  SHARED_CLI_BIN="$CLI_BIN"
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

setup_balance_audio_mock_runtime

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
    override)
      RUNNER_LABEL="override"
      ;;
    prebuilt)
      if [[ "$RUNNER_LABEL" == "none" ]]; then
        RUNNER_LABEL="prebuilt"
      fi
      ;;
  esac
}

runner_from_log_balance() {
  local log_path="$1"
  if grep -q "runner: override" "$log_path" 2>/dev/null; then
    printf 'override'
  elif grep -q "runner: prebuilt" "$log_path" 2>/dev/null; then
    printf 'prebuilt'
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
    echo "audio-runtime: $BALANCE_AUDIO_RUNTIME_NOTE"
    echo "log: $(display_path "$ROOT" "$log_path")"
  } >> "$ENTRYPOINT_LOG"

  local -a env_args=(
    CHECK_SAMPLES_OUT_DIR="$mode_workspace/samples"
    MARKITDOWN_CLI_TMP_DIR="$mode_workspace/cli"
    CHECK_FAILURE_DIFF_DIR="$DIFF_DIR"
    CHECK_FAILURE_RAW_DIR="$RAW_DIR/failures"
    CHECK_FAILURE_REPORTS_DIR="$FAILURE_REPORTS_DIR"
    SAMPLES_KEEP_TMP=1
    MARKITDOWN_PROGRESS_FD=3
  )
  if [[ -n "${SHARED_CLI_BIN:-}" ]]; then
    env_args+=(MARKITDOWN_CLI="$SHARED_CLI_BIN")
  fi

  set +e
  env "${env_args[@]}" "$SAMPLE_IMPL" "${args[@]}" 3>&1 >"$log_path" 2>&1
  local status=$?
  set -e

  local runner checks failures line_status notes
  runner="$(runner_from_log_balance "$log_path")"
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

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$mode_short" "$fmt" "$line_status" "$runner" "$checks" "$failures" "$(display_path "$ROOT" "$log_path")" "$notes" >> "$SUMMARY_PATH"
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
    echo "- Diff directory: $(display_path "$ROOT" "$DIFF_DIR")"
    echo "- Failure raw artifacts: $(display_path "$ROOT" "$RAW_DIR/failures")"
    echo
    local report
    for report in $(find "$FAILURE_REPORTS_DIR" -maxdepth 1 -type f -name '*.md' | sort); do
      local name
      name="$(basename "$report" .md)"
      echo "- [$name]($(display_path "$ROOT" "$report"))"
    done
  } > "$index_path"
}

write_summary_md() {
  local status="$1"
  local finished_at="$2"
  local duration="$3"
  local lanes="markdown, rag, assets, ocr"
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
    echo "Run directory: $(display_path "$ROOT" "$CHECK_RUN_DIR")"
    echo "Runner: $RUNNER_LABEL"
    echo "Started: $STARTED_AT"
    echo "Finished: $finished_at"
    echo "Duration: ${duration}s"
    echo
    echo "## What was checked"
    echo
    echo "External main manifest lane checks for the balance CLI gate: txt, csv, tsv, srt, vtt, json, jsonl, ndjson, ipynb, xml, yaml, toml, html, markdown, eml, tex, rst, asciidoc, zip, epub, odt, ods, odp, docx, xlsx, pptx, pdf, wav, mp3, m4a, and ocr."
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
    if [[ "$BALANCE_AUDIO_MOCK_ACTIVE" -eq 1 ]]; then
      echo "- Audio runtime: deterministic mock (\`samples/helpers/mock_vosk_wrapper.py\` with repo-local mock \`ffmpeg\`)"
    else
      echo "- Audio runtime: $BALANCE_AUDIO_RUNTIME_NOTE"
    fi
    echo
    echo "## Where to look next"
    echo
    echo "- Full log: $(display_path "$ROOT" "$ENTRYPOINT_LOG")"
    echo "- Workspace scratch: $(display_path "$ROOT" "$WORKSPACE_DIR")"
    if [[ "$failure_report_count" == "0" ]]; then
      echo "- Failure artifacts: none"
    else
      echo "- Failure index: $(display_path "$ROOT" "$REPORTS_DIR/failures.md")"
      echo "- Failed diffs: $(display_path "$ROOT" "$DIFF_DIR")"
      echo "- Failed raw output: $(display_path "$ROOT" "$RAW_DIR/failures")"
      echo "- Failed reports: $(display_path "$ROOT" "$FAILURE_REPORTS_DIR")"
    fi
  } > "$SUMMARY_MD_PATH"
}

print_result() {
  local status="$1"
  local result_label="pass"
  [[ "$status" -eq 0 ]] || result_label="fail"
  echo "balance-gate: format=$(format_display) mode=$([[ -n "$ONLY_MODE" ]] && mode_display "$ONLY_MODE" || printf 'all') runner=$RUNNER_LABEL"
  echo "run: $(display_path "$ROOT" "$CHECK_RUN_DIR")"
  echo "result: $result_label  formats=$(format_display) rows=$CHECKS_TOTAL checked=$CHECKS_TOTAL skipped=$SKIPPED_TOTAL failed=$FAILED_TOTAL"
  echo "summary: $(display_path "$ROOT" "$SUMMARY_MD_PATH")"
  echo "details: $(display_path "$ROOT" "$CHECK_RUN_DIR")"
}

overall_status=0
if [[ -n "$ONLY_MODE" ]]; then
  run_impl "$ONLY_MODE" || overall_status=$?
else
  run_impl "markdown" || overall_status=$?
  run_impl "rag" || overall_status=$?
  run_impl "assets" || overall_status=$?
  run_impl "ocr" || overall_status=$?
fi

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FINISH_SECONDS="$(date +%s)"
DURATION_SECONDS=$((FINISH_SECONDS - START_SECONDS))
write_failures_index
write_summary_md "$overall_status" "$FINISHED_AT" "$DURATION_SECONDS"
print_result "$overall_status"

exit "$overall_status"
