#!/usr/bin/env bash

source "$ROOT/samples/helpers/shared/regression_common.sh"

signal_suite_supported_formats_array() {
  local raw="${SIGNAL_SUITE_SUPPORTED_FORMATS:-}"
  local -a formats=()
  if [[ -n "$raw" ]]; then
    read -r -a formats <<< "$raw"
  fi
  printf '%s\n' "${formats[@]}"
}

signal_suite_supported_formats_compact() {
  local -a formats=()
  local fmt
  while IFS= read -r fmt; do
    [[ -n "$fmt" ]] && formats+=("$fmt")
  done < <(signal_suite_supported_formats_array)
  local IFS=","
  printf '%s' "${formats[*]}"
}

signal_suite_supported_shortcuts_compact() {
  local shortcuts=()
  local fmt
  while IFS= read -r fmt; do
    [[ -n "$fmt" ]] && shortcuts+=("--$fmt")
  done < <(signal_suite_supported_formats_array)
  local IFS=", "
  printf '%s' "${shortcuts[*]}"
}

signal_suite_format_is_supported() {
  local target="${1-}"
  local fmt
  while IFS= read -r fmt; do
    [[ -z "$fmt" ]] && continue
    if [[ "$fmt" == "$target" ]]; then
      return 0
    fi
  done < <(signal_suite_supported_formats_array)
  return 1
}

signal_suite_fail_unsupported_format() {
  local format="${1-}"
  echo "unsupported format for $SIGNAL_SUITE_ENTRYPOINT: $format" >&2
  if [[ -n "${SIGNAL_SUITE_SUPPORTED_FORMATS:-}" ]]; then
    echo "supported formats: $(signal_suite_supported_formats_compact)" >&2
    echo "supported shortcuts: $(signal_suite_supported_shortcuts_compact)" >&2
  fi
  exit 1
}

signal_suite_set_filter_format() {
  local format="${1-}"
  if [[ -n "$FILTER_FORMAT" ]]; then
    echo "choose only one format filter" >&2
    signal_suite_usage_common >&2
    exit 1
  fi
  if [[ -n "${SIGNAL_SUITE_SUPPORTED_FORMATS:-}" ]] && ! signal_suite_format_is_supported "$format"; then
    signal_suite_fail_unsupported_format "$format"
  fi
  FILTER_FORMAT="$format"
}

signal_suite_require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "missing required signal-suite variable: $name" >&2
    exit 1
  fi
}

signal_suite_print_missing_corpus() {
  local missing_path="$1"
  echo "$SIGNAL_SUITE_MISSING_TITLE" >&2
  echo >&2
  echo "* expected: $(display_path "$ROOT" "$SIGNAL_SUITE_CORPUS_ROOT")/" >&2
  echo "* missing: $(display_path "$ROOT" "$missing_path")" >&2
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    echo "* $line" >&2
  done <<< "${SIGNAL_SUITE_MISSING_HINTS:-}"
}

signal_suite_usage_common() {
  cat <<EOF
Usage: ./$SIGNAL_SUITE_ENTRYPOINT [--format FORMAT|--formats FORMAT|--pdf] [--id ROW_ID] [--source SOURCE_ID] [--help]

$SIGNAL_SUITE_USAGE_TITLE

Default behavior:
  * runs only the $SIGNAL_SUITE_CORPUS_LABEL corpus from ./markitdown-quality-lab
  * expects:
      ./markitdown-quality-lab/$SIGNAL_SUITE_CORPUS_DIRNAME/
      ./markitdown-quality-lab/$SIGNAL_SUITE_CORPUS_DIRNAME/MANIFEST.tsv
  * does not fall back to repo-local quality rows
$SIGNAL_SUITE_USAGE_EXTRA
  * keeps raw per-row outputs for executed rows under \`raw/\`
  * writes non-pass per-row reports under \`reports/\`
  * uses \`workspace/\` only as scratch CLI temp space
EOF
  if [[ -n "${SIGNAL_SUITE_SUPPORTED_FORMATS:-}" ]]; then
    cat <<EOF

Supported formats:
  * values for --format / --formats: $(signal_suite_supported_formats_compact)
  * quick shortcuts: $(signal_suite_supported_shortcuts_compact)
EOF
  fi
  cat <<EOF

Examples:
$SIGNAL_SUITE_USAGE_EXAMPLES
EOF
}

signal_suite_run() {
  signal_suite_require_var SIGNAL_SUITE_ENTRYPOINT
  signal_suite_require_var SIGNAL_SUITE_USAGE_TITLE
  signal_suite_require_var SIGNAL_SUITE_CORPUS_LABEL
  signal_suite_require_var SIGNAL_SUITE_CORPUS_DIRNAME
  signal_suite_require_var SIGNAL_SUITE_TMP_ROOT
  signal_suite_require_var SIGNAL_SUITE_RUN_ID_PREFIX
  signal_suite_require_var SIGNAL_SUITE_RESULT_PREFIX
  signal_suite_require_var SIGNAL_SUITE_CHECK
  signal_suite_require_var SIGNAL_SUITE_LAB_ROOT
  signal_suite_require_var SIGNAL_SUITE_CORPUS_ROOT
  signal_suite_require_var SIGNAL_SUITE_MANIFEST_PATH
  signal_suite_require_var SIGNAL_SUITE_SUMMARY_INTRO
  signal_suite_require_var SIGNAL_SUITE_MISSING_TITLE

  FILTER_FORMAT=""
  declare -a EXTRA_RUNNER_ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format|--formats)
        [[ $# -ge 2 ]] || {
          echo "missing value for $1" >&2
          signal_suite_usage_common >&2
          exit 1
        }
        signal_suite_set_filter_format "$2"
        shift 2
        ;;
      --id|--source|--cli-arg)
        [[ $# -ge 2 ]] || {
          echo "missing value for $1" >&2
          signal_suite_usage_common >&2
          exit 1
        }
        EXTRA_RUNNER_ARGS+=("$1" "$2")
        shift 2
        ;;
      --list|--profile)
        EXTRA_RUNNER_ARGS+=("$1")
        shift
        ;;
      -h|--help)
        signal_suite_usage_common
        exit 0
        ;;
      --*)
        shortcut_format="${1#--}"
        if [[ -n "${SIGNAL_SUITE_SUPPORTED_FORMATS:-}" ]] && signal_suite_format_is_supported "$shortcut_format"; then
          signal_suite_set_filter_format "$shortcut_format"
          shift
          continue
        fi
        signal_suite_fail_unsupported_format "$shortcut_format"
        ;;
      *)
        echo "unknown argument: $1" >&2
        signal_suite_usage_common >&2
        exit 1
        ;;
    esac
  done

  RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
  RUN_LABEL="all"
  if [[ -n "$FILTER_FORMAT" ]]; then
    RUN_LABEL="$FILTER_FORMAT"
  fi
  QUALITY_RUN_ID="${QUALITY_RUN_ID:-${SIGNAL_SUITE_RUN_ID_PREFIX}-${RUN_LABEL}-${RUN_STAMP}-$$}"
  QUALITY_TMP_DIR="${QUALITY_TMP_DIR:-$SIGNAL_SUITE_TMP_ROOT/runs/$QUALITY_RUN_ID}"
  LOG_DIR="$QUALITY_TMP_DIR/logs"
  DIFF_DIR="$QUALITY_TMP_DIR/diff"
  WORKSPACE_DIR="$QUALITY_TMP_DIR/workspace"
  RAW_DIR="$QUALITY_TMP_DIR/raw"
  REPORTS_DIR="$QUALITY_TMP_DIR/reports"
  QUALITY_CLI_TMP_DIR="${QUALITY_CLI_TMP_DIR:-$WORKSPACE_DIR}"
  SUMMARY_PATH="$QUALITY_TMP_DIR/summary.tsv"
  SUMMARY_MD_PATH="$QUALITY_TMP_DIR/summary.md"
  RUN_LOG_PATH="$LOG_DIR/entrypoint.log"

  if [[ ! -d "$SIGNAL_SUITE_LAB_ROOT" ]]; then
    signal_suite_print_missing_corpus "$SIGNAL_SUITE_LAB_ROOT"
    exit 1
  fi

  if [[ ! -d "$SIGNAL_SUITE_CORPUS_ROOT" ]]; then
    signal_suite_print_missing_corpus "$SIGNAL_SUITE_CORPUS_ROOT"
    exit 1
  fi

  if [[ ! -f "$SIGNAL_SUITE_MANIFEST_PATH" ]]; then
    signal_suite_print_missing_corpus "$SIGNAL_SUITE_MANIFEST_PATH"
    exit 1
  fi

  declare -a runner_args=(
    --require-lab
    --corpus-root "$SIGNAL_SUITE_CORPUS_ROOT"
    --lab-manifest "$SIGNAL_SUITE_MANIFEST_PATH"
  )
  if [[ -n "$FILTER_FORMAT" ]]; then
    runner_args+=(--format "$FILTER_FORMAT")
  fi
  if [[ -n "${SIGNAL_SUITE_FORBID_FEATURE:-}" ]]; then
    runner_args+=(--forbid-feature "$SIGNAL_SUITE_FORBID_FEATURE")
  fi
  if ((${#EXTRA_RUNNER_ARGS[@]} > 0)); then
    runner_args+=("${EXTRA_RUNNER_ARGS[@]}")
  fi

  mkdir -p "$LOG_DIR" "$DIFF_DIR" "$WORKSPACE_DIR" "$RAW_DIR" "$REPORTS_DIR"
  STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  START_SECONDS="$(date +%s)"

  if declare -F signal_suite_before_run >/dev/null 2>&1; then
    signal_suite_before_run "$QUALITY_TMP_DIR" "$LOG_DIR" "$RUN_LABEL"
  fi

  local -a env_exports=(
    QUALITY_RUN_ID="$QUALITY_RUN_ID"
    QUALITY_TMP_ROOT="$SIGNAL_SUITE_TMP_ROOT"
    QUALITY_TMP_DIR="$QUALITY_TMP_DIR"
    MARKITDOWN_CLI_TMP_DIR="$QUALITY_CLI_TMP_DIR"
    MARKITDOWN_QUALITY_LAB="$SIGNAL_SUITE_LAB_ROOT"
    MARKITDOWN_PROGRESS_FD=3
  )
  if declare -p SIGNAL_SUITE_ENV_EXPORTS >/dev/null 2>&1; then
    env_exports+=("${SIGNAL_SUITE_ENV_EXPORTS[@]}")
  fi

  set +e
  env "${env_exports[@]}" bash "$SIGNAL_SUITE_CHECK" "${runner_args[@]}" 3>&1 >"$RUN_LOG_PATH" 2>&1
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
    echo "Command: ./$SIGNAL_SUITE_ENTRYPOINT$(append_command_args "${ORIGINAL_ARGS[@]}")"
    echo "Run directory: $(display_path "$ROOT" "$QUALITY_TMP_DIR")"
    echo "Manifest: $(display_path "$ROOT" "$SIGNAL_SUITE_MANIFEST_PATH")"
    echo "Runner: $runner_label"
    echo "Started: $STARTED_AT"
    echo "Finished: $FINISHED_AT"
    echo "Duration: ${DURATION_SECONDS}s"
    if declare -F signal_suite_write_summary_extra >/dev/null 2>&1; then
      signal_suite_write_summary_extra
    fi
    echo
    echo "## What was checked"
    echo
    echo "$SIGNAL_SUITE_SUMMARY_INTRO"
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
    echo "- Full log: $(display_path "$ROOT" "$RUN_LOG_PATH")"
    echo "- Raw executed outputs: $(display_path "$ROOT" "$RAW_DIR")"
    echo "- Non-pass index: $(display_path "$ROOT" "$REPORTS_DIR/nonpass.md")"
    echo "- Row reports: $(display_path "$ROOT" "$REPORTS_DIR/rows")"
    echo "- Workspace scratch: $(display_path "$ROOT" "$WORKSPACE_DIR")"
  } > "$SUMMARY_MD_PATH"

  echo "$SIGNAL_SUITE_RESULT_PREFIX: format=$format_label manifest=$(display_path "$ROOT" "$SIGNAL_SUITE_MANIFEST_PATH") runner=$runner_label"
  echo "run: $(display_path "$ROOT" "$QUALITY_TMP_DIR")"
  if [[ "$status" -ne 0 ]]; then
    echo "result: fail  rows=$rows checked=$checked skipped=$skipped failed=$failed"
    echo "summary: $(display_path "$ROOT" "$SUMMARY_MD_PATH")"
    echo "details: $(display_path "$ROOT" "$QUALITY_TMP_DIR")"
    echo "log: $(display_path "$ROOT" "$RUN_LOG_PATH")"
    return "$status"
  fi
  if [[ -n "$FILTER_FORMAT" && "$rows" == "0" ]]; then
    echo "note: no fallback; no repo-local samples were used"
  fi
  echo "result: $result_label  rows=$rows checked=$checked skipped=$skipped failed=$failed"
  echo "summary: $(display_path "$ROOT" "$SUMMARY_MD_PATH")"
  echo "details: $(display_path "$ROOT" "$QUALITY_TMP_DIR")"
}
