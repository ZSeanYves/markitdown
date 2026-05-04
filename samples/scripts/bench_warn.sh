#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
THRESHOLDS_PATH="$ROOT/samples/benchmark/perf_thresholds.tsv"
DEFAULT_SMOKE_INPUT="$TMP_ROOT/bench/smoke/summary.tsv"
DEFAULT_COMPARE_INPUT="$TMP_ROOT/bench/compare/summary.tsv"
DEFAULT_BATCH_PROFILE_INPUT="$TMP_ROOT/bench/batch_profile/comparison-summary.tsv"
STRICT_MODE=0
RUN_ALL=0
SUITE=""
INPUT_OVERRIDE=""
WARNINGS=0
CHECKS=0
SKIPPED=0

trim_field() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

lower_field() {
  printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]'
}

is_number() {
  [[ "${1-}" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

usage() {
  cat <<EOF
usage: ./samples/scripts/bench_warn.sh [--suite SUITE] [--all] [--strict] [--input PATH] [--thresholds PATH]

Suites:
  batch_profile   read .tmp/bench/batch_profile/comparison-summary.tsv
  smoke           read .tmp/bench/smoke/summary.tsv
  compare         reserved for future warning policy support

Options:
  --suite SUITE       suite to check: batch_profile | smoke | compare
  --all               run all supported suites with checked-in thresholds
  --input PATH        override input TSV path for the selected suite
  --thresholds PATH   override threshold policy TSV
  --strict            exit 1 when warnings are found
  --help              show this help

Notes:
  * This tool is a manual warning layer, not a CI hard gate.
  * Default mode reports warnings but exits 0.
  * Missing input or malformed policy/input exits 2.
EOF
}

is_supported_suite() {
  case "${1-}" in
    batch_profile|smoke|compare)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

default_input_for_suite() {
  case "${1-}" in
    batch_profile)
      printf '%s' "$DEFAULT_BATCH_PROFILE_INPUT"
      ;;
    smoke)
      printf '%s' "$DEFAULT_SMOKE_INPUT"
      ;;
    compare)
      printf '%s' "$DEFAULT_COMPARE_INPUT"
      ;;
    *)
      printf ''
      ;;
  esac
}

metric_supported_for_suite() {
  local suite="${1-}"
  local metric="${2-}"
  case "$suite:$metric" in
    batch_profile:speedup|batch_profile:single_process_batch_ms|batch_profile:process_per_file_ms|batch_profile:peak_rss_kb_batch|batch_profile:failure_count)
      return 0
      ;;
    smoke:median_ms|smoke:avg_ms|smoke:output_bytes_last|smoke:asset_count_last|smoke:failed)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

load_policy_lines_for_suite() {
  local suite="$1"
  local path="$2"
  POLICY_LINES=()

  if [[ ! -f "$path" ]]; then
    echo "threshold policy not found: $path" >&2
    exit 2
  fi

  local line_no=0
  local header_seen=0
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line_no=$((line_no + 1))
    local line
    line="$(trim_field "$raw_line")"
    [[ -z "$line" ]] && continue
    [[ "${line#\#}" != "$line" ]] && continue

    IFS=$'\t' read -r col1 col2 col3 col4 col5 col6 extra <<< "$line"
    col1="$(trim_field "${col1-}")"
    col2="$(trim_field "${col2-}")"
    col3="$(trim_field "${col3-}")"
    col4="$(trim_field "${col4-}")"
    col5="$(trim_field "${col5-}")"
    col6="$(trim_field "${col6-}")"

    if [[ $header_seen -eq 0 ]]; then
      header_seen=1
      if [[ "$col1" != "suite" || "$col2" != "key" || "$col3" != "metric" || "$col4" != "direction" || "$col5" != "warn_value" ]]; then
        echo "malformed threshold header in $path" >&2
        exit 2
      fi
      continue
    fi

    [[ "$col1" != "$suite" ]] && continue

    if [[ -n "${extra-}" ]]; then
      echo "malformed threshold row $line_no in $path: expected 6 columns" >&2
      exit 2
    fi

    if [[ -z "$col2" || -z "$col3" || -z "$col4" || -z "$col5" ]]; then
      echo "malformed threshold row $line_no in $path: missing required fields" >&2
      exit 2
    fi

    case "$col4" in
      min|max)
        ;;
      *)
        echo "unsupported direction '$col4' on threshold row $line_no" >&2
        exit 2
        ;;
    esac

    if ! is_number "$col5"; then
      echo "non-numeric warn_value '$col5' on threshold row $line_no" >&2
      exit 2
    fi

    if ! metric_supported_for_suite "$suite" "$col3"; then
      echo "unsupported metric '$col3' for suite '$suite' on threshold row $line_no" >&2
      exit 2
    fi

    POLICY_LINES+=("$col2"$'\t'"$col3"$'\t'"$col4"$'\t'"$col5"$'\t'"$col6")
  done < "$path"
}

lookup_metric_value() {
  local suite="$1"
  local input_path="$2"
  local key="$3"
  local metric="$4"

  case "$suite" in
    batch_profile)
      awk -F '\t' -v want_key="$key" -v want_metric="$metric" '
        NR == 1 {
          for (i = 1; i <= NF; i++) {
            header[$i] = i
          }
          next
        }
        {
          row_key = $header["format"] ":" $header["group_size"] ":" $header["metadata_enabled"]
          if (row_key == want_key) {
            found = 1
            if (!(want_metric in header)) {
              print "__MISSING_METRIC__"
              exit
            }
            print $(header[want_metric])
            exit
          }
        }
        END {
          if (NR <= 1) {
            print "__EMPTY__"
          } else if (!found) {
            print "__MISSING_KEY__"
          }
        }
      ' "$input_path"
      ;;
    smoke)
      awk -F '\t' -v want_key="$key" -v want_metric="$metric" '
        NR == 1 {
          for (i = 1; i <= NF; i++) {
            header[$i] = i
          }
          next
        }
        {
          if ($header["sample"] == want_key) {
            found = 1
            if (!(want_metric in header)) {
              print "__MISSING_METRIC__"
              exit
            }
            print $(header[want_metric])
            exit
          }
        }
        END {
          if (NR <= 1) {
            print "__EMPTY__"
          } else if (!found) {
            print "__MISSING_KEY__"
          }
        }
      ' "$input_path"
      ;;
    compare)
      echo "__UNSUPPORTED_SUITE__"
      ;;
    *)
      echo "__UNSUPPORTED_SUITE__"
      ;;
  esac
}

compare_value() {
  local actual="$1"
  local direction="$2"
  local threshold="$3"
  awk -v actual="$actual" -v direction="$direction" -v threshold="$threshold" '
    BEGIN {
      if (direction == "min") {
        exit(!(actual + 0 >= threshold + 0))
      }
      if (direction == "max") {
        exit(!(actual + 0 <= threshold + 0))
      }
      exit(2)
    }
  '
}

relation_text() {
  case "${1-}" in
    min)
      printf '>='
      ;;
    max)
      printf '<='
      ;;
    *)
      printf '?'
      ;;
  esac
}

validate_input_header() {
  local suite="$1"
  local input_path="$2"
  if [[ ! -f "$input_path" ]]; then
    echo "benchmark input not found for suite '$suite': $input_path" >&2
    exit 2
  fi
  if [[ ! -s "$input_path" ]]; then
    echo "benchmark input is empty for suite '$suite': $input_path" >&2
    exit 2
  fi

  local header
  header="$(head -n 1 "$input_path")"
  case "$suite" in
    batch_profile)
      [[ "$header" == *$'format\tgroup_size\tmetadata_enabled'* ]] || {
        echo "unexpected batch_profile header in $input_path" >&2
        exit 2
      }
      ;;
    smoke)
      [[ "$header" == *$'format\tsample\truns\tfailed'* ]] || {
        echo "unexpected smoke header in $input_path" >&2
        exit 2
      }
      ;;
    compare)
      [[ "$header" == *$'runner\tformat\tsample'* ]] || {
        echo "unexpected compare header in $input_path" >&2
        exit 2
      }
      ;;
  esac
}

run_suite_check() {
  local suite="$1"
  local input_path="$2"

  echo "==> benchmark warning check: $suite"

  if [[ "$suite" == "compare" ]]; then
    echo "[info] compare suite warning policies are future work in v1"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  validate_input_header "$suite" "$input_path"
  load_policy_lines_for_suite "$suite" "$THRESHOLDS_PATH"

  if [[ "${#POLICY_LINES[@]}" -eq 0 ]]; then
    echo "[info] no threshold rows configured for suite '$suite'"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  local suite_warnings=0
  local line
  for line in "${POLICY_LINES[@]}"; do
    IFS=$'\t' read -r key metric direction warn_value notes <<< "$line"
    local actual
    actual="$(lookup_metric_value "$suite" "$input_path" "$key" "$metric")"
    case "$actual" in
      __UNSUPPORTED_SUITE__)
        echo "unsupported suite lookup: $suite" >&2
        exit 2
        ;;
      __EMPTY__)
        echo "empty input for suite '$suite': $input_path" >&2
        exit 2
        ;;
      __MISSING_METRIC__)
        echo "metric '$metric' not found in input for suite '$suite': $input_path" >&2
        exit 2
        ;;
      __MISSING_KEY__)
        echo "[warn] $key $metric missing in input; threshold skipped"
        WARNINGS=$((WARNINGS + 1))
        suite_warnings=$((suite_warnings + 1))
        CHECKS=$((CHECKS + 1))
        continue
        ;;
    esac

    if ! is_number "$actual"; then
      echo "non-numeric metric '$metric' for key '$key' in suite '$suite': $actual" >&2
      exit 2
    fi

    CHECKS=$((CHECKS + 1))
    if compare_value "$actual" "$direction" "$warn_value"; then
      printf '[ok]   %s %s=%s %s %s\n' "$key" "$metric" "$actual" "$(relation_text "$direction")" "$warn_value"
    else
      printf '[warn] %s %s=%s not %s %s\n' "$key" "$metric" "$actual" "$(relation_text "$direction")" "$warn_value"
      [[ -n "$notes" ]] && printf '       note: %s\n' "$notes"
      WARNINGS=$((WARNINGS + 1))
      suite_warnings=$((suite_warnings + 1))
    fi
  done

  echo
  echo "BENCHMARK WARNINGS ($suite): $suite_warnings"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      [[ $# -lt 2 ]] && {
        echo "missing value for --suite" >&2
        usage >&2
        exit 2
      }
      SUITE="$2"
      shift 2
      ;;
    --input)
      [[ $# -lt 2 ]] && {
        echo "missing value for --input" >&2
        usage >&2
        exit 2
      }
      INPUT_OVERRIDE="$2"
      shift 2
      ;;
    --thresholds)
      [[ $# -lt 2 ]] && {
        echo "missing value for --thresholds" >&2
        usage >&2
        exit 2
      }
      THRESHOLDS_PATH="$2"
      shift 2
      ;;
    --all)
      RUN_ALL=1
      shift
      ;;
    --strict)
      STRICT_MODE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ $RUN_ALL -eq 1 && -n "$SUITE" ]]; then
  echo "cannot combine --all with --suite" >&2
  exit 2
fi

if [[ $RUN_ALL -eq 0 && -z "$SUITE" ]]; then
  echo "expected --suite SUITE or --all" >&2
  usage >&2
  exit 2
fi

if [[ -n "$SUITE" ]] && ! is_supported_suite "$SUITE"; then
  echo "unsupported suite: $SUITE" >&2
  exit 2
fi

if [[ $RUN_ALL -eq 1 && -n "$INPUT_OVERRIDE" ]]; then
  echo "--input can only be used with a single --suite" >&2
  exit 2
fi

declare -a suites_to_run=()
if [[ $RUN_ALL -eq 1 ]]; then
  suites_to_run=("batch_profile" "smoke" "compare")
else
  suites_to_run=("$SUITE")
fi

for suite_name in "${suites_to_run[@]}"; do
  suite_input="$INPUT_OVERRIDE"
  if [[ -z "$suite_input" ]]; then
    suite_input="$(default_input_for_suite "$suite_name")"
  fi
  run_suite_check "$suite_name" "$suite_input"
done

echo
echo "BENCHMARK CHECKS: $CHECKS"
echo "BENCHMARK WARNINGS: $WARNINGS"
echo "BENCHMARK SKIPPED SUITES: $SKIPPED"

if [[ $STRICT_MODE -eq 1 && $WARNINGS -gt 0 ]]; then
  exit 1
fi
exit 0
