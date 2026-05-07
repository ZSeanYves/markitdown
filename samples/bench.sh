#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"

SUITE=""
declare -a FORWARD_ARGS=()

usage() {
  cat <<'EOF'
Usage: ./samples/bench.sh --suite SUITE [suite-args...]
   or: ./samples/bench.sh SUITE [suite-args...]

Public suites:
  smoke         checked-in same-machine smoke benchmark
  compare       overlap-only comparison against Microsoft MarkItDown
  batch-profile batch-vs-normal profiling harness

Examples:
  ./samples/bench.sh --suite smoke
  ./samples/bench.sh --suite smoke --kind smoke
  ./samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
  ./samples/bench.sh --suite batch-profile --formats xlsx,html,zip,epub,docx,pptx,pdf --counts 1,3 --iterations 1 --warmup 0 --memory auto

Notes:
  * samples/bench.sh is the public benchmark entrypoint.
  * samples/scripts/bench_*.sh remain internal implementation scripts.
EOF
}

has_forward_flag() {
  local wanted="$1"
  local arg
  for arg in "${FORWARD_ARGS[@]}"; do
    [[ "$arg" == "$wanted" ]] && return 0
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --suite" >&2
        usage >&2
        exit 1
      fi
      SUITE="$2"
      shift 2
      ;;
    smoke|compare|batch-profile)
      if [[ -z "$SUITE" ]]; then
        SUITE="$1"
      else
        FORWARD_ARGS+=("$1")
      fi
      shift
      ;;
    -h|--help)
      if [[ -n "$SUITE" ]]; then
        FORWARD_ARGS+=("$1")
        shift
      else
        usage
        exit 0
      fi
      ;;
    *)
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$SUITE" ]]; then
  echo "benchmark suite is required" >&2
  usage >&2
  exit 1
fi

SCRIPT_PATH=""
RESULT_ROOT=""
RESULTS_PATH=""
SUMMARY_PATH=""
declare -a EXTRA_PATHS=()

case "$SUITE" in
  smoke)
    SCRIPT_PATH="$ROOT/samples/scripts/bench_smoke.sh"
    RESULT_ROOT="$TMP_ROOT/bench/smoke"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    if ! has_forward_flag "--kind"; then
      FORWARD_ARGS=(--kind smoke "${FORWARD_ARGS[@]}")
    fi
    ;;
  compare)
    SCRIPT_PATH="$ROOT/samples/scripts/bench_compare_markitdown.sh"
    RESULT_ROOT="$TMP_ROOT/bench/compare"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    ;;
  batch-profile)
    SCRIPT_PATH="$ROOT/samples/scripts/bench_batch_profile.sh"
    RESULT_ROOT="$TMP_ROOT/bench/batch_profile"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    EXTRA_PATHS=(
      "$RESULT_ROOT/startup-summary.tsv"
      "$RESULT_ROOT/comparison-summary.tsv"
      "$RESULT_ROOT/file_results.tsv"
    )
    ;;
  *)
    echo "unknown benchmark suite: $SUITE" >&2
    usage >&2
    exit 1
    ;;
esac

echo "==> benchmark suite: $SUITE"
echo "runner script: $SCRIPT_PATH"
"$SCRIPT_PATH" "${FORWARD_ARGS[@]}"

echo "BENCHMARK SUITE COMPLETED"
echo "- suite: $SUITE"
echo "- result_root: $RESULT_ROOT"
echo "- results_jsonl: $RESULTS_PATH"
echo "- summary_tsv: $SUMMARY_PATH"
if declare -p EXTRA_PATHS >/dev/null 2>&1; then
  for extra_path in "${EXTRA_PATHS[@]:-}"; do
    [[ -n "$extra_path" ]] || continue
    echo "- artifact: $extra_path"
  done
fi
