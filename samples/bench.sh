#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/samples/helpers/bench/bench_v2_common.sh"

BENCH_TMP_ROOT="${MARKITDOWN_BENCH_TMP_ROOT:-${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}/bench}"
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
BENCH_RUN_ID="${BENCH_RUN_ID:-all-${RUN_STAMP}-$$}"
BENCH_RUN_DIR=""
SUMMARY_PATH=""
MANIFEST_PATH=""
FORMAT_FILTER=""
ITERATIONS=""
WARMUP=""
PROFILE=""
REQUESTED_LAYER=""
USER_OUTPUT_PATH=""
USER_OUTPUT_DIR=""
declare -a ORIGINAL_ARGS=()
if [[ $# -gt 0 ]]; then
  ORIGINAL_ARGS=("$@")
fi

usage() {
  cat <<'EOF'
Usage:
  ./samples/bench.sh [--layer parser|convert|cli|compare] [--format fmt[,fmt]] [--manifest PATH] [--iterations N] [--warmup N] [--output PATH|--output-dir DIR] [--profile PROFILE]

Default:
  Run all benchmark layers against quality-lab external_bench and write an
  isolated run under .tmp/bench/runs/<run-id>/. This can be heavier than a
  smoke check; use --layer to focus one layer.

Examples:
  ./samples/bench.sh --format html --iterations 1 --warmup 0
  ./samples/bench.sh --layer parser --format html --iterations 1 --warmup 0
  ./samples/bench.sh --layer cli --profile normal --format pdf --iterations 1 --warmup 0

Layers:
  parser   parser layer benchmark using bench/parser_layer and quality-lab external_bench
  convert  convert/convert.parse_to_ir benchmark using quality-lab external_bench
  cli      native CLI process benchmark using quality-lab external_bench
  compare  explicit Microsoft MarkItDown comparison layer using quality-lab external_bench

Output:
  Each run contains logs/, summary.tsv, diff/, workspace/, raw/, and reports/.

Notes:
  * samples/bench.sh is the only public benchmark entrypoint.
  * Benchmark corpus and manifest rows must come from quality-lab external_bench.
  * Suite-style benchmark entrypoints are retired; use --layer to filter layers.
  * Main-process regression samples are not a performance benchmark corpus.
EOF
}

deprecated_suite() {
  cat >&2 <<'EOF'
--suite is retired for benchmark entrypoints.
Use --layer parser|convert|cli|compare with an external_bench manifest instead.
EOF
}

require_value() {
  local flag="$1"
  local count="$2"
  if [[ "$count" -lt 2 ]]; then
    echo "missing value for $flag" >&2
    usage >&2
    exit 1
  fi
}

is_tmp_path() {
  local path="$1"
  case "$path" in
    .tmp|.tmp/*|"$ROOT/.tmp"|"$ROOT/.tmp"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_tmp_path() {
  local label="$1"
  local path="$2"
  if ! is_tmp_path "$path"; then
    echo "$label must be inside .tmp: $path" >&2
    exit 1
  fi
}

resolve_manifest_path() {
  if [[ -n "$MANIFEST_PATH" ]]; then
    if [[ ! -f "$MANIFEST_PATH" ]]; then
      echo "external_bench manifest missing: $MANIFEST_PATH" >&2
      bench_v2_fail_missing_manifest
      exit 1
    fi
    return
  fi
  MANIFEST_PATH="$(bench_v2_resolve_manifest "$ROOT")" || {
    bench_v2_fail_missing_manifest
    exit 1
  }
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
  printf './samples/bench.sh'
  local arg
  if ((${#ORIGINAL_ARGS[@]} > 0)); then
    for arg in "${ORIGINAL_ARGS[@]}"; do
      printf ' %q' "$arg"
    done
  fi
}

sanitize_component() {
  printf '%s' "${1-}" | tr -c '[:alnum:]_-' '-'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer)
      require_value "$1" "$#"
      REQUESTED_LAYER="$2"
      shift 2
      ;;
    --format)
      require_value "$1" "$#"
      bench_v2_require_non_empty_token_filter "$1" "$2" || exit 1
      FORMAT_FILTER="$2"
      shift 2
      ;;
    --manifest)
      require_value "$1" "$#"
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --iterations)
      require_value "$1" "$#"
      ITERATIONS="$2"
      shift 2
      ;;
    --warmup)
      require_value "$1" "$#"
      WARMUP="$2"
      shift 2
      ;;
    --output)
      require_value "$1" "$#"
      USER_OUTPUT_PATH="$2"
      require_tmp_path "--output" "$USER_OUTPUT_PATH"
      shift 2
      ;;
    --output-dir)
      require_value "$1" "$#"
      USER_OUTPUT_DIR="${2%/}"
      require_tmp_path "--output-dir" "$USER_OUTPUT_DIR"
      shift 2
      ;;
    --profile)
      require_value "$1" "$#"
      PROFILE="$2"
      shift 2
      ;;
    --corpus)
      echo "corpus now comes from external_bench manifest; use --manifest PATH or MARKITDOWN_BENCH_LAB / MARKITDOWN_QUALITY_LAB" >&2
      exit 1
      ;;
    --suite)
      deprecated_suite
      usage >&2
      exit 1
      ;;
    --runs|--kind|--formats|--counts|--group-sizes|--models|--memory)
      echo "$1 belongs to deprecated suite-specific benchmark entrypoints; use --layer with external_bench" >&2
      exit 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    smoke|compare|batch-profile|cold-start|cold_start|doc-parse|doc_parse|product-path|product_path)
      deprecated_suite
      usage >&2
      exit 1
      ;;
    *)
      echo "unknown benchmark argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$REQUESTED_LAYER" in
  ""|parser|convert|cli|compare)
    ;;
  *)
    echo "unknown benchmark layer: $REQUESTED_LAYER" >&2
    usage >&2
    exit 1
    ;;
esac

if [[ -n "$USER_OUTPUT_DIR" && -n "$USER_OUTPUT_PATH" ]]; then
  echo "choose at most one of --output and --output-dir" >&2
  exit 1
fi

if [[ -n "$USER_OUTPUT_DIR" ]]; then
  BENCH_RUN_DIR="$USER_OUTPUT_DIR"
  SUMMARY_PATH="$BENCH_RUN_DIR/summary.tsv"
elif [[ -n "$USER_OUTPUT_PATH" ]]; then
  SUMMARY_PATH="$USER_OUTPUT_PATH"
  BENCH_RUN_DIR="$(dirname "$USER_OUTPUT_PATH")"
else
  BENCH_RUN_DIR="$BENCH_TMP_ROOT/runs/$BENCH_RUN_ID"
  SUMMARY_PATH="$BENCH_RUN_DIR/summary.tsv"
fi

LOG_DIR="$BENCH_RUN_DIR/logs"
DIFF_DIR="$BENCH_RUN_DIR/diff"
WORKSPACE_DIR="$BENCH_RUN_DIR/workspace"
RAW_DIR="$BENCH_RUN_DIR/raw"
REPORTS_DIR="$BENCH_RUN_DIR/reports"
SUMMARY_MD_PATH="$BENCH_RUN_DIR/summary.md"
ENTRYPOINT_LOG="$LOG_DIR/entrypoint.log"
mkdir -p "$LOG_DIR" "$DIFF_DIR" "$WORKSPACE_DIR" "$RAW_DIR" "$REPORTS_DIR"
: > "$ENTRYPOINT_LOG"

resolve_manifest_path
bench_v2_require_external_bench_header "$MANIFEST_PATH"

declare -a LAYERS=()
if [[ -n "$REQUESTED_LAYER" ]]; then
  LAYERS=("$REQUESTED_LAYER")
else
  LAYERS=(parser convert cli compare)
fi

printf 'layer\tstatus\trows\titerations\twarmup\tmedian_ms\trunner\tsummary_path\tlog_path\tnotes\n' > "$SUMMARY_PATH"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_SECONDS="$(date +%s)"
ROWS_TOTAL=0
FAILED_LAYERS=0
RUNNER_LABEL="none"

layer_filter_label() {
  if [[ -n "$REQUESTED_LAYER" ]]; then
    printf '%s' "$REQUESTED_LAYER"
  else
    printf 'all'
  fi
}

format_filter_label() {
  if [[ -n "$FORMAT_FILTER" ]]; then
    printf '%s' "$FORMAT_FILTER"
  else
    printf 'all'
  fi
}

update_bench_runner_label() {
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

bench_runner_from_log() {
  local log_path="$1"
  if grep -q "runner: built" "$log_path" 2>/dev/null; then
    printf 'built'
  elif grep -q "runner: prebuilt" "$log_path" 2>/dev/null; then
    printf 'prebuilt'
  elif grep -q "runner: moon run\\|runner: moon-run" "$log_path" 2>/dev/null; then
    printf 'moon-run'
  else
    printf 'none'
  fi
}

bench_rows_from_summary() {
  local summary="$1"
  if [[ ! -f "$summary" ]]; then
    printf '0'
    return
  fi
  awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$summary"
}

bench_median_from_summary() {
  local summary="$1"
  if [[ ! -f "$summary" ]]; then
    printf 'n/a'
    return
  fi
  awk -F '\t' '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i == "p50_ms") {
          p50 = i
        }
      }
      next
    }
    p50 > 0 && $p50 != "" {
      value = $p50 + 0
      if (!seen || value > max) {
        max = value
      }
      seen = 1
    }
    END {
      if (seen) {
        printf "%.3fms", max
      } else {
        printf "n/a"
      }
    }
  ' "$summary"
}

run_layer() {
  local layer="$1"
  local layer_dir="$RAW_DIR/$layer"
  local log_path="$LOG_DIR/$layer.entrypoint.log"
  local build_log="$LOG_DIR/build.log"
  mkdir -p "$layer_dir"

  local helper=""
  declare -a args=()
  case "$layer" in
    parser)
      helper="$ROOT/samples/helpers/bench/bench_doc_parse_helper.sh"
      args=(--layer parser --manifest "$MANIFEST_PATH" --output "$layer_dir/summary.tsv")
      ;;
    convert)
      helper="$ROOT/samples/helpers/bench/bench_convert_layer.sh"
      args=(--layer convert --manifest "$MANIFEST_PATH" --output "$layer_dir/summary.tsv")
      ;;
    cli)
      helper="$ROOT/samples/helpers/bench/bench_cli_layer.sh"
      args=(--layer cli --manifest "$MANIFEST_PATH" --output-dir "$layer_dir")
      ;;
    compare)
      helper="$ROOT/samples/helpers/bench/bench_compare_markitdown.sh"
      args=(--layer compare --manifest "$MANIFEST_PATH" --output-dir "$layer_dir")
      ;;
  esac

  if [[ -n "$FORMAT_FILTER" ]]; then
    args+=(--format "$FORMAT_FILTER")
  fi
  if [[ -n "$ITERATIONS" ]]; then
    args+=(--iterations "$ITERATIONS")
  fi
  if [[ -n "$WARMUP" ]]; then
    args+=(--warmup "$WARMUP")
  fi
  if [[ -n "$PROFILE" && "$layer" != "compare" ]]; then
    args+=(--profile "$PROFILE")
  elif [[ -n "$PROFILE" && "$layer" == "compare" ]]; then
    echo "compare layer ignores --profile $PROFILE" >> "$log_path"
  fi

  {
    echo "layer: $layer"
    echo "log: $(display_path "$log_path")"
  } >> "$ENTRYPOINT_LOG"
  set +e
  MARKITDOWN_TMP_DIR="$WORKSPACE_DIR" BENCH_BUILD_LOG="$build_log" MARKITDOWN_PROGRESS_FD=3 "$helper" "${args[@]}" 3>&1 >> "$log_path" 2>&1
  local status=$?
  set -e

  local summary="$layer_dir/summary.tsv"
  local rows median runner line_status notes
  rows="$(bench_rows_from_summary "$summary")"
  median="$(bench_median_from_summary "$summary")"
  runner="$(bench_runner_from_log "$log_path")"
  update_bench_runner_label "$runner"
  ROWS_TOTAL=$((ROWS_TOTAL + rows))
  if [[ "$status" -eq 0 ]]; then
    line_status="pass"
    notes=""
  else
    line_status="fail"
    notes="exit=$status"
    FAILED_LAYERS=$((FAILED_LAYERS + 1))
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$layer" "$line_status" "$rows" "${ITERATIONS:-default}" "${WARMUP:-default}" "$median" "$runner" "$(display_path "$summary")" "$(display_path "$log_path")" "$notes" >> "$SUMMARY_PATH"
  cat "$log_path" >> "$ENTRYPOINT_LOG"
  printf '%-10s %-5s rows=%s iterations=%s warmup=%s median=%s runner=%s' \
    "$layer" "$line_status" "$rows" "${ITERATIONS:-default}" "${WARMUP:-default}" "$median" "$runner"
  if [[ "$line_status" == "fail" && -f "$build_log" ]]; then
    printf ' log=%s' "$(display_path "$build_log")"
  fi
  printf '\n'
  if [[ "$status" -ne 0 ]]; then
    return "$status"
  fi
}

overall_status=0
for layer in "${LAYERS[@]}"; do
  echo "layer: $layer"
  if run_layer "$layer"; then
    :
  else
    overall_status=$?
    break
  fi
done

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FINISH_SECONDS="$(date +%s)"
DURATION_SECONDS=$((FINISH_SECONDS - START_SECONDS))
result_label="pass"
result_word="PASS"
if [[ "$overall_status" -ne 0 ]]; then
  result_label="fail"
  result_word="FAIL"
fi

{
  echo "# Run summary"
  echo
  echo "Status: $result_word"
  echo "Command: $(command_text)"
  echo "Run directory: $(display_path "$BENCH_RUN_DIR")"
  echo "Manifest: $(display_path "$MANIFEST_PATH")"
  echo "Runner: $RUNNER_LABEL"
  echo "Started: $STARTED_AT"
  echo "Finished: $FINISHED_AT"
  echo "Duration: ${DURATION_SECONDS}s"
  echo
  echo "## What was checked"
  echo
  echo "External benchmark rows from external_bench. Results are same-machine and same-corpus directional feedback, not universal performance guarantees."
  echo
  echo "## Result"
  echo
  echo "- Layers: ${LAYERS[*]}"
  echo "- Formats: $(format_filter_label)"
  echo "- Rows: $ROWS_TOTAL"
  echo "- Checked: $ROWS_TOTAL"
  echo "- Skipped: 0"
  echo "- Failed: $FAILED_LAYERS"
  echo "- Failed layers: $FAILED_LAYERS"
  echo
  echo "## Where to look next"
  echo
  echo "- Full log: $(display_path "$ENTRYPOINT_LOG")"
  echo "- Diffs: $(display_path "$DIFF_DIR")"
  echo "- Raw output: $(display_path "$RAW_DIR")"
  echo "- Reports: $(display_path "$REPORTS_DIR")"
} > "$SUMMARY_MD_PATH"

echo "bench: format=$(format_filter_label) layer=$(layer_filter_label) runner=$RUNNER_LABEL"
echo "manifest: $(display_path "$MANIFEST_PATH")"
echo "run: $(display_path "$BENCH_RUN_DIR")"
echo "result: $result_label  layers=${LAYERS[*]} rows=$ROWS_TOTAL failed=$FAILED_LAYERS"
echo "summary: $(display_path "$SUMMARY_MD_PATH")"
echo "details: $(display_path "$BENCH_RUN_DIR")"

exit "$overall_status"
