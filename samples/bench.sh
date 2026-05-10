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
  doc-parse     direct doc_parse library benchmark wrapper
  product-path  same-process product-path attribution benchmark wrapper

Examples:
  ./samples/bench.sh --suite smoke
  ./samples/bench.sh --suite smoke --kind smoke
  ./samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
  ./samples/bench.sh --suite batch-profile --formats xlsx,html,zip,epub,docx,pptx,pdf --counts 1,3 --iterations 1 --warmup 0 --memory auto
  ./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
  ./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
  ./samples/bench.sh --suite product-path --smoke

Notes:
  * samples/bench.sh is the public benchmark entrypoint.
  * suite implementations now live under `samples/helpers/`.
  * `samples/helpers/bench_*_helper.sh` are internal focused rerun helpers.
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

forward_value() {
  local wanted="$1"
  local value=""
  local i=0
  while [[ $i -lt ${#FORWARD_ARGS[@]} ]]; do
    if [[ "${FORWARD_ARGS[i]}" == "$wanted" ]]; then
      if (( i + 1 < ${#FORWARD_ARGS[@]} )); then
        value="${FORWARD_ARGS[i + 1]}"
      fi
    fi
    i=$((i + 1))
  done
  printf '%s' "$value"
}

extract_forward_value() {
  local wanted="$1"
  local result_var="$2"
  local value=""
  local -a filtered=()
  local i=0

  while [[ $i -lt ${#FORWARD_ARGS[@]} ]]; do
    local arg="${FORWARD_ARGS[i]}"
    if [[ "$arg" == "$wanted" ]]; then
      if (( i + 1 >= ${#FORWARD_ARGS[@]} )); then
        echo "missing value for $wanted" >&2
        exit 1
      fi
      value="${FORWARD_ARGS[i + 1]}"
      i=$((i + 2))
      continue
    fi
    filtered+=("$arg")
    i=$((i + 1))
  done

  FORWARD_ARGS=("${filtered[@]}")
  printf -v "$result_var" '%s' "$value"
}

dirname_of_path() {
  local path="$1"
  if [[ "$path" == */* ]]; then
    printf '%s\n' "${path%/*}"
  else
    printf '.\n'
  fi
}

raw_runs_path() {
  local path="$1"
  if [[ "$path" == *.tsv ]]; then
    printf '%s\n' "${path%.tsv}.runs.tsv"
  else
    printf '%s.runs.tsv\n' "$path"
  fi
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
    smoke|compare|batch-profile|doc-parse|doc_parse|product-path|product_path)
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
RESULTS_LABEL="results_jsonl"
SUMMARY_PATH=""
declare -a EXTRA_PATHS=()
HELP_MODE=false

if has_forward_flag "--help" || has_forward_flag "-h"; then
  HELP_MODE=true
fi

case "$SUITE" in
  smoke)
    SCRIPT_PATH="$ROOT/samples/helpers/bench_smoke.sh"
    RESULT_ROOT="$TMP_ROOT/bench/smoke"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    if ! has_forward_flag "--kind"; then
      FORWARD_ARGS=(--kind smoke "${FORWARD_ARGS[@]}")
    fi
    ;;
  compare)
    SCRIPT_PATH="$ROOT/samples/helpers/bench_compare_markitdown.sh"
    RESULT_ROOT="$TMP_ROOT/bench/compare"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    ;;
  batch-profile)
    SCRIPT_PATH="$ROOT/samples/helpers/bench_batch_profile.sh"
    RESULT_ROOT="$TMP_ROOT/bench/batch_profile"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    EXTRA_PATHS=(
      "$RESULT_ROOT/startup-summary.tsv"
      "$RESULT_ROOT/comparison-summary.tsv"
      "$RESULT_ROOT/file_results.tsv"
    )
    ;;
  doc-parse|doc_parse)
    SUITE="doc-parse"
    SCRIPT_PATH="$ROOT/samples/helpers/bench_doc_parse_helper.sh"
    kind_value=""
    extract_forward_value "--kind" kind_value
    if [[ -n "$kind_value" && "$kind_value" != "library" ]]; then
      echo "doc-parse suite only supports --kind library" >&2
      exit 1
    fi
    SUMMARY_PATH="$(forward_value "--output")"
    if [[ -z "$SUMMARY_PATH" ]]; then
      SUMMARY_PATH="$TMP_ROOT/bench/doc_parse/summary.tsv"
    fi
    RESULT_ROOT="$(dirname_of_path "$SUMMARY_PATH")"
    RESULTS_PATH="$(raw_runs_path "$SUMMARY_PATH")"
    RESULTS_LABEL="raw_runs_tsv"
    ;;
  product-path|product_path)
    SUITE="product-path"
    SCRIPT_PATH="$ROOT/samples/helpers/bench_product_path_helper.sh"
    kind_value=""
    extract_forward_value "--kind" kind_value
    if [[ -n "$kind_value" && "$kind_value" != "stage" ]]; then
      echo "product-path suite only supports --kind stage" >&2
      exit 1
    fi
    RESULT_ROOT="$(forward_value "--output-dir")"
    if [[ -z "$RESULT_ROOT" ]]; then
      RESULT_ROOT="$TMP_ROOT/bench/product_path"
    fi
    if has_forward_flag "--smoke"; then
      EXTRA_PATHS=(
        "$RESULT_ROOT/stage-plan.tsv"
        "$RESULT_ROOT/sample-plan.tsv"
      )
    elif ! $HELP_MODE; then
      SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
      RESULTS_PATH="$RESULT_ROOT/summary.runs.tsv"
      RESULTS_LABEL="raw_runs_tsv"
    fi
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

if $HELP_MODE; then
  exit 0
fi

echo "BENCHMARK SUITE COMPLETED"
echo "- suite: $SUITE"
echo "- result_root: $RESULT_ROOT"
if [[ -n "$RESULTS_PATH" ]]; then
  echo "- $RESULTS_LABEL: $RESULTS_PATH"
fi
if [[ -n "$SUMMARY_PATH" ]]; then
  echo "- summary_tsv: $SUMMARY_PATH"
fi
if declare -p EXTRA_PATHS >/dev/null 2>&1; then
  for extra_path in "${EXTRA_PATHS[@]:-}"; do
    [[ -n "$extra_path" ]] || continue
    echo "- artifact: $extra_path"
  done
fi
