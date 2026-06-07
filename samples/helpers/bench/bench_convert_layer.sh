#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/bench/bench_v2_common.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
RESULT_ROOT="$TMP_ROOT/bench/convert"
DEFAULT_OUTPUT="$RESULT_ROOT/summary.tsv"

MANIFEST_PATH=""
OUTPUT_PATH="$DEFAULT_OUTPUT"
FORMAT_FILTER=""
ITERATIONS="${BENCH_ITERATIONS:-10}"
WARMUP="${BENCH_WARMUP:-2}"
PROFILE=""
DEBUG_SELECT=0
declare -a FORWARD_ARGS=()

usage() {
  cat <<'EOF'
usage: ./samples/bench.sh --layer convert [--manifest PATH] [--format fmt[,fmt]] [--iterations N] [--warmup N] [--output PATH|--output-dir DIR] [--profile PROFILE] [--debug-select]

Notes:
  * convert layer corpus rows come only from quality-lab external_bench/MANIFEST.tsv.
  * This layer calls convert/convert.parse_to_ir inside a native benchmark runner.
  * It does not call the CLI and does not write Markdown output.
EOF
}

external_bench_required() {
  bench_v2_fail_missing_manifest
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

is_non_negative_int() {
  [[ "${1-}" =~ ^[0-9]+$ ]]
}

resolve_manifest_path() {
  if [[ -n "$MANIFEST_PATH" ]]; then
    if [[ ! -f "$MANIFEST_PATH" ]]; then
      echo "external_bench manifest missing: $MANIFEST_PATH" >&2
      external_bench_required
      exit 1
    fi
    bench_v2_require_external_bench_header "$MANIFEST_PATH"
    return
  fi

  MANIFEST_PATH="$(bench_v2_resolve_manifest "$ROOT")" || {
    external_bench_required
    exit 1
  }
  bench_v2_require_external_bench_header "$MANIFEST_PATH"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer)
      require_value "$1" "$#"
      if [[ "$2" != "convert" ]]; then
        echo "bench_convert_layer only supports --layer convert" >&2
        exit 1
      fi
      shift 2
      ;;
    --manifest)
      require_value "$1" "$#"
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --format)
      require_value "$1" "$#"
      bench_v2_require_non_empty_token_filter "$1" "$2" || exit 1
      FORMAT_FILTER="$2"
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
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --output-dir)
      require_value "$1" "$#"
      OUTPUT_PATH="${2%/}/summary.tsv"
      shift 2
      ;;
    --profile)
      require_value "$1" "$#"
      PROFILE="$2"
      shift 2
      ;;
    --debug-select)
      DEBUG_SELECT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --corpus|--suite)
      echo "$1 is not supported for benchmark v2 layers; use external_bench manifest rows" >&2
      exit 1
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! is_non_negative_int "$ITERATIONS"; then
  echo "BENCH_ITERATIONS/--iterations must be a non-negative integer" >&2
  exit 1
fi
if [[ "$ITERATIONS" -eq 0 ]]; then
  echo "iterations must be greater than zero" >&2
  exit 1
fi
if ! is_non_negative_int "$WARMUP"; then
  echo "BENCH_WARMUP/--warmup must be a non-negative integer" >&2
  exit 1
fi

resolve_manifest_path

FORWARD_ARGS=(--layer convert --manifest "$MANIFEST_PATH" --iterations "$ITERATIONS" --warmup "$WARMUP" --output "$OUTPUT_PATH")
if [[ -n "$FORMAT_FILTER" ]]; then
  FORWARD_ARGS+=(--format "$FORMAT_FILTER")
fi
if [[ -n "$PROFILE" ]]; then
  FORWARD_ARGS+=(--profile "$PROFILE")
fi
if [[ "$DEBUG_SELECT" -eq 1 ]]; then
  FORWARD_ARGS+=(--debug-select)
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

echo "==> convert layer benchmark"
echo "manifest: $MANIFEST_PATH"
echo "output: $OUTPUT_PATH"

RUNNER="$(bench_v2_resolve_native_runner "$ROOT" "bench/convert_layer" "*/build/bench/convert_layer/convert_layer.exe" "convert layer" "$ROOT/_build/native/debug/build/bench/convert_layer/convert_layer.exe")"
echo "runner_source: bench/convert_layer" >&2
PROGRESS_LABELS_PATH="${OUTPUT_PATH}.progress-labels"
bench_v2_selected_row_labels "$MANIFEST_PATH" "convert" "$FORMAT_FILTER" > "$PROGRESS_LABELS_PATH"
PROGRESS_TOTAL="$(wc -l < "$PROGRESS_LABELS_PATH" | tr -d '[:space:]')"
bench_v2_run_with_progress "$ROOT" "$RUNNER" "$OUTPUT_PATH" "$PROGRESS_LABELS_PATH" "$PROGRESS_TOTAL" "${FORWARD_ARGS[@]}"

echo "BENCHMARK SUITE COMPLETED"
echo "- layer: convert"
echo "- result_root: $(dirname "$OUTPUT_PATH")"
echo "- summary_tsv: $OUTPUT_PATH"
if [[ "$OUTPUT_PATH" == *.tsv ]]; then
  echo "- raw_runs_tsv: ${OUTPUT_PATH%.tsv}.runs.tsv"
else
  echo "- raw_runs_tsv: ${OUTPUT_PATH}.runs.tsv"
fi
