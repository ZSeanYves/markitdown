#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"

SUITE=""
RUNS_OVERRIDE=""
declare -a FORWARD_ARGS=()

usage() {
  cat <<'EOF'
Usage: ./samples/bench.sh [--suite SUITE] [--runs N] [suite-args...]
   or: ./samples/bench.sh SUITE [suite-args...]

Public suites:
  smoke         checked-in same-machine smoke benchmark
  compare       overlap-only comparison against Microsoft MarkItDown
  batch-profile batch-vs-normal profiling harness
  cold-start    focused cold CLI startup benchmark
  doc-parse     direct doc_parse library benchmark wrapper
  product-path  same-process product-path attribution benchmark wrapper

Examples:
  ./samples/bench.sh
  ./samples/bench.sh --suite smoke
  ./samples/bench.sh --suite compare --iterations 1 --warmup 0 --corpus samples/benchmark/compare_corpus.tsv
  ./samples/bench.sh --suite batch-profile --formats xlsx,html,zip,epub,docx,pptx,pdf --counts 1,3 --iterations 1 --warmup 0 --memory auto
  ./samples/bench.sh --suite cold-start --kind cli --iterations 50 --warmup 5
  ./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
  ./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
  ./samples/bench.sh --suite product-path --smoke

Notes:
  * samples/bench.sh is the public benchmark entrypoint.
  * The default suite is smoke.
  * suite implementations now live under `samples/helpers/bench/`.
  * `samples/helpers/bench/*.sh` are internal focused rerun helpers.
EOF
}

has_forward_flag() {
  local wanted="$1"
  local arg
  for arg in "${FORWARD_ARGS[@]-}"; do
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

display_path() {
  local path="$1"
  if [[ -z "$path" ]]; then
    printf '%s' ""
  elif [[ "$path" == "$ROOT" ]]; then
    printf '.'
  elif [[ "$path" == "$ROOT/"* ]]; then
    printf '%s' "${path#$ROOT/}"
  else
    printf '%s' "$path"
  fi
}

print_data_row_count() {
  local path="$1"
  if [[ -f "$path" ]]; then
    awk 'NR > 1 && NF > 0 {count++} END {print count + 0}' "$path"
  else
    printf '0'
  fi
}

count_failed_cases() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf '0'
    return
  fi

  awk -F '\t' '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        header[$i] = i
      }
      next
    }
    NF == 0 {
      next
    }
    ("failed" in header) && ($(header["failed"]) + 0 != 0) {
      count++
      next
    }
    ("status" in header) {
      status = $(header["status"])
      if (status != "pass" && status != "success" && status != "ok" && status != "skipped") {
        count++
      }
    }
    END {
      print count + 0
    }
  ' "$path"
}

failed_case_list() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    return
  fi

  awk -F '\t' '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        header[$i] = i
      }
      next
    }
    NF == 0 {
      next
    }
    {
      failed = 0
      if ("failed" in header && $(header["failed"]) + 0 != 0) {
        failed = 1
      } else if ("status" in header) {
        status = $(header["status"])
        if (status != "pass" && status != "success" && status != "ok" && status != "skipped") {
          failed = 1
        }
      }
      if (!failed) {
        next
      }

      label = ""
      if ("runner" in header && "sample" in header) {
        label = $(header["runner"]) "/" $(header["sample"])
      } else if ("sample" in header) {
        label = $(header["sample"])
      } else if ("case" in header) {
        label = $(header["case"])
      } else if ("format" in header && "stage" in header) {
        label = $(header["format"]) "/" $(header["stage"])
      } else if ("format" in header) {
        label = $(header["format"])
      } else {
        label = "row-" NR
      }

      print label
      shown++
      if (shown >= 10) {
        exit
      }
    }
  ' "$path"
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
    --runs)
      if [[ $# -lt 2 ]]; then
        echo "missing value for --runs" >&2
        usage >&2
        exit 1
      fi
      RUNS_OVERRIDE="$2"
      shift 2
      ;;
    smoke|compare|batch-profile|cold-start|cold_start|doc-parse|doc_parse|product-path|product_path)
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
  SUITE="smoke"
fi

if [[ -n "$RUNS_OVERRIDE" ]]; then
  if ! [[ "$RUNS_OVERRIDE" =~ ^[0-9]+$ ]] || [[ "$RUNS_OVERRIDE" == "0" ]]; then
    echo "--runs must be a positive integer" >&2
    exit 1
  fi
fi

if [[ "$SUITE" == "smoke" ]]; then
  if ! has_forward_flag "--kind"; then
    if [[ "${#FORWARD_ARGS[@]}" -gt 0 ]]; then
      FORWARD_ARGS=(--kind smoke "${FORWARD_ARGS[@]}")
    else
      FORWARD_ARGS=(--kind smoke)
    fi
  fi
  if [[ -n "$RUNS_OVERRIDE" ]] && ! has_forward_flag "--iterations"; then
    if [[ "${#FORWARD_ARGS[@]}" -gt 0 ]]; then
      FORWARD_ARGS=(--iterations "$RUNS_OVERRIDE" "${FORWARD_ARGS[@]}")
    else
      FORWARD_ARGS=(--iterations "$RUNS_OVERRIDE")
    fi
  fi
elif [[ -n "$RUNS_OVERRIDE" ]]; then
  if ! has_forward_flag "--iterations"; then
    if [[ "${#FORWARD_ARGS[@]}" -gt 0 ]]; then
      FORWARD_ARGS=(--iterations "$RUNS_OVERRIDE" "${FORWARD_ARGS[@]}")
    else
      FORWARD_ARGS=(--iterations "$RUNS_OVERRIDE")
    fi
  fi
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
    SCRIPT_PATH="$ROOT/samples/helpers/bench/bench_smoke.sh"
    RESULT_ROOT="$TMP_ROOT/bench/smoke"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    ;;
  compare)
    SCRIPT_PATH="$ROOT/samples/helpers/bench/bench_compare_markitdown.sh"
    RESULT_ROOT="$TMP_ROOT/bench/compare"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    ;;
  batch-profile)
    SCRIPT_PATH="$ROOT/samples/helpers/bench/bench_batch_profile.sh"
    RESULT_ROOT="$TMP_ROOT/bench/batch_profile"
    RESULTS_PATH="$RESULT_ROOT/results.jsonl"
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    EXTRA_PATHS=(
      "$RESULT_ROOT/startup-summary.tsv"
      "$RESULT_ROOT/comparison-summary.tsv"
      "$RESULT_ROOT/file_results.tsv"
    )
    ;;
  cold-start|cold_start)
    SUITE="cold-start"
    SCRIPT_PATH="$ROOT/samples/helpers/bench/bench_cold_start_helper.sh"
    kind_value=""
    extract_forward_value "--kind" kind_value
    if [[ -n "$kind_value" && "$kind_value" != "cli" ]]; then
      echo "cold-start suite only supports --kind cli" >&2
      exit 1
    fi
    RESULT_ROOT="$(forward_value "--output-dir")"
    if [[ -z "$RESULT_ROOT" ]]; then
      RESULT_ROOT="$TMP_ROOT/bench/cold_start"
    fi
    SUMMARY_PATH="$RESULT_ROOT/summary.tsv"
    RESULTS_PATH="$RESULT_ROOT/summary.runs.tsv"
    RESULTS_LABEL="raw_runs_tsv"
    EXTRA_PATHS=(
      "$RESULT_ROOT/startup_profile.runs.tsv"
      "$RESULT_ROOT/startup_profile.summary.tsv"
    )
    ;;
  doc-parse|doc_parse)
    SUITE="doc-parse"
    SCRIPT_PATH="$ROOT/samples/helpers/bench/bench_doc_parse_helper.sh"
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
    SCRIPT_PATH="$ROOT/samples/helpers/bench/bench_product_path_helper.sh"
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

export MARKITDOWN_CLI_TMP_DIR="${MARKITDOWN_CLI_TMP_DIR:-$RESULT_ROOT/workspace}"
if $HELP_MODE; then
  if [[ "${#FORWARD_ARGS[@]}" -gt 0 ]]; then
    exec "$SCRIPT_PATH" "${FORWARD_ARGS[@]}"
  fi
  exec "$SCRIPT_PATH"
fi

mkdir -p "$RESULT_ROOT"
RUN_LOG_PATH="$RESULT_ROOT/entrypoint.log"

set +e
if [[ "${#FORWARD_ARGS[@]}" -gt 0 ]]; then
  "$SCRIPT_PATH" "${FORWARD_ARGS[@]}" >"$RUN_LOG_PATH" 2>&1
else
  "$SCRIPT_PATH" >"$RUN_LOG_PATH" 2>&1
fi
status=$?
set -e

cases_run="0"
if [[ -n "$SUMMARY_PATH" ]]; then
  cases_run="$(print_data_row_count "$SUMMARY_PATH")"
elif [[ -n "$RESULTS_PATH" && -f "$RESULTS_PATH" ]]; then
  cases_run="$(awk 'NF > 0 {count++} END {print count + 0}' "$RESULTS_PATH")"
fi

failure_count="0"
if [[ -n "$SUMMARY_PATH" ]]; then
  failure_count="$(count_failed_cases "$SUMMARY_PATH")"
fi

runs_value="$RUNS_OVERRIDE"
if [[ -z "$runs_value" ]]; then
  runs_value="$(forward_value "--iterations")"
fi
if [[ -z "$runs_value" ]]; then
  runs_value="${BENCH_ITERATIONS:-1}"
fi

if [[ "$status" -ne 0 ]]; then
  echo "BENCHMARK FAILED"
  echo
  echo "* suite: $SUITE"
  echo "* cases: $cases_run"
  echo "* failures: $failure_count"
  if [[ -n "$SUMMARY_PATH" && -f "$SUMMARY_PATH" ]]; then
    mapfile -t failed_cases < <(failed_case_list "$SUMMARY_PATH")
    if [[ "${#failed_cases[@]}" -gt 0 ]]; then
      echo "* failed_cases: ${failed_cases[*]}"
    fi
  fi
  if [[ -n "$SUMMARY_PATH" ]]; then
    echo "* summary: $(display_path "$SUMMARY_PATH")"
  fi
  if [[ -n "$RESULTS_PATH" ]]; then
    echo "* raw: $(display_path "$RESULTS_PATH")"
  fi
  if [[ "${#EXTRA_PATHS[@]}" -gt 0 ]]; then
    for extra_path in "${EXTRA_PATHS[@]}"; do
      [[ -n "$extra_path" ]] || continue
      echo "* artifact: $(display_path "$extra_path")"
    done
  fi
  echo "* log: $(display_path "$RUN_LOG_PATH")"
  exit "$status"
fi

echo "BENCHMARK PASSED"
echo
echo "* suite: $SUITE"
echo "* cases: $cases_run"
echo "* failures: $failure_count"
if [[ -n "$SUMMARY_PATH" ]]; then
  echo "* summary: $(display_path "$SUMMARY_PATH")"
fi
if [[ -n "$RESULTS_PATH" ]]; then
  echo "* raw: $(display_path "$RESULTS_PATH")"
fi
