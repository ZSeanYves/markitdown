#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
BENCH_ROOT="$TMP_ROOT/bench/smoke"
CORPUS_PATH="$ROOT/samples/benchmark/corpus.tsv"
RESULTS_PATH="$BENCH_ROOT/results.jsonl"
RUNS_TSV_PATH="$BENCH_ROOT/.runs.tsv"
SUMMARY_PATH="$BENCH_ROOT/summary.tsv"
TIMER_PRECISION="unknown"
NOW_MS_VALUE="0"
ITERATIONS="${BENCH_ITERATIONS:-1}"
WARMUP="${BENCH_WARMUP:-0}"
KIND="${BENCH_KIND:-smoke}"

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

json_bool() {
  local raw
  raw="$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    true|1|yes)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

trim_field() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

resolve_input_path() {
  local path="${1-}"
  if [[ "$path" == /* ]]; then
    printf '%s' "$path"
  else
    printf '%s/%s' "$ROOT" "$path"
  fi
}

file_size_bytes() {
  local path="${1-}"
  if [[ -f "$path" ]]; then
    wc -c < "$path" | tr -d '[:space:]'
  else
    printf '0'
  fi
}

count_assets() {
  local sample_dir="${1-}"
  local asset_dir="$sample_dir/assets"
  if [[ -d "$asset_dir" ]]; then
    find "$asset_dir" -type f | wc -l | tr -d '[:space:]'
  else
    printf '0'
  fi
}

timestamp_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

set_now_ms() {
  local raw
  raw="$(date +%s%N 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ ${#raw} -gt 10 ]]; then
    TIMER_PRECISION="ms"
    NOW_MS_VALUE="$((raw / 1000000))"
    return
  fi

  raw="$(LC_ALL=C LANG=C perl -MTime::HiRes=time -e 'print int(time()*1000), qq(\n)' 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    TIMER_PRECISION="ms"
    NOW_MS_VALUE="$raw"
    return
  fi

  local secs
  secs="$(date +%s 2>/dev/null || true)"
  if [[ "$secs" =~ ^[0-9]+$ ]]; then
    TIMER_PRECISION="s"
    NOW_MS_VALUE="$((secs * 1000))"
    return
  fi

  TIMER_PRECISION="unknown"
  NOW_MS_VALUE="0"
}

git_rev() {
  git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || true
}

usage() {
  cat <<EOF
usage: ./samples/scripts/bench_smoke.sh [--kind KIND] [--iterations N] [--warmup N]

Environment overrides:
  BENCH_KIND         benchmark tier: smoke | image | metadata | extended | all
                     (default: smoke)
  BENCH_ITERATIONS   number of measured iterations per sample (default: 1)
  BENCH_WARMUP       number of unrecorded warmup runs per sample (default: 0)
  MARKITDOWN_TMP_DIR override temp root (default: \$ROOT/.tmp)
EOF
}

is_non_negative_int() {
  [[ "${1-}" =~ ^[0-9]+$ ]]
}

is_supported_kind() {
  case "${1-}" in
    smoke|image|metadata|extended|all)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

should_run_kind() {
  local selected="${1-}"
  local row_kind="${2-}"
  if [[ "$selected" == "all" ]]; then
    return 0
  fi
  [[ "$selected" == "$row_kind" ]]
}

generate_summary() {
  if [[ ! -s "$RUNS_TSV_PATH" ]]; then
    printf 'format\tsample\truns\tfailed\tmin_ms\tmedian_ms\tmax_ms\tavg_ms\toutput_bytes_last\tasset_count_last\n' \
      > "$SUMMARY_PATH"
    return
  fi

  awk -F '\t' '
    function sort_numeric(values, n,    i, j, tmp) {
      for (i = 2; i <= n; i++) {
        tmp = values[i]
        j = i - 1
        while (j >= 1 && values[j] + 0 > tmp + 0) {
          values[j + 1] = values[j]
          j--
        }
        values[j + 1] = tmp
      }
    }

    function format_metric(value) {
      if (value == int(value)) {
        return sprintf("%d", int(value))
      }
      return sprintf("%.1f", value)
    }

    function median_of(list,    n, values, lower, upper) {
      n = split(list, values, " ")
      sort_numeric(values, n)
      if (n % 2 == 1) {
        return format_metric(values[(n + 1) / 2] + 0)
      }
      lower = n / 2
      upper = lower + 1
      return format_metric((values[lower] + values[upper]) / 2.0)
    }

    BEGIN {
      OFS = "\t"
      print "format", "sample", "runs", "failed", "min_ms", "median_ms", "max_ms", "avg_ms", "output_bytes_last", "asset_count_last"
    }

    {
      key = $1 SUBSEP $2
      if (!(key in seen)) {
        seen[key] = 1
        order[++order_count] = key
        formats[key] = $1
        samples[key] = $2
      }

      runs[key]++
      if ($4 + 0 != 0) {
        failed[key]++
      }

      elapsed = $5 + 0
      if (!(key in min_ms) || elapsed < min_ms[key]) {
        min_ms[key] = elapsed
      }
      if (!(key in max_ms) || elapsed > max_ms[key]) {
        max_ms[key] = elapsed
      }
      sum_ms[key] += elapsed

      if (times[key] == "") {
        times[key] = elapsed
      } else {
        times[key] = times[key] " " elapsed
      }

      output_last[key] = $6
      asset_last[key] = $7
    }

    END {
      for (i = 1; i <= order_count; i++) {
        key = order[i]
        avg = sum_ms[key] / runs[key]
        print formats[key], samples[key], runs[key], failed[key] + 0, min_ms[key], median_of(times[key]), max_ms[key], format_metric(avg), output_last[key], asset_last[key]
      }
    }
  ' "$RUNS_TSV_PATH" > "$SUMMARY_PATH"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kind)
      [[ $# -lt 2 ]] && {
        echo "missing value for --kind" >&2
        usage >&2
        exit 1
      }
      KIND="$2"
      shift 2
      ;;
    --iterations)
      [[ $# -lt 2 ]] && {
        echo "missing value for --iterations" >&2
        usage >&2
        exit 1
      }
      ITERATIONS="$2"
      shift 2
      ;;
    --warmup)
      [[ $# -lt 2 ]] && {
        echo "missing value for --warmup" >&2
        usage >&2
        exit 1
      }
      WARMUP="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
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

if ! is_supported_kind "$KIND"; then
  echo "BENCH_KIND/--kind must be one of: smoke, image, metadata, extended, all" >&2
  exit 1
fi

if ! is_non_negative_int "$WARMUP"; then
  echo "BENCH_WARMUP/--warmup must be a non-negative integer" >&2
  exit 1
fi

if [[ "$ITERATIONS" -eq 0 ]]; then
  echo "iterations must be greater than zero" >&2
  exit 1
fi

if [[ ! -f "$CORPUS_PATH" ]]; then
  echo "benchmark corpus missing: $CORPUS_PATH" >&2
  exit 1
fi

echo "==> warming Moon build"
if ! (cd "$ROOT" && moon build >/dev/null); then
  echo "moon build failed" >&2
  exit 1
fi

rm -rf "$BENCH_ROOT"
mkdir -p "$BENCH_ROOT"
: > "$RESULTS_PATH"
: > "$RUNS_TSV_PATH"

GIT_REV="$(git_rev)"
run_count=0
fail_count=0

echo "==> iterations: $ITERATIONS"
echo "==> warmup: $WARMUP"
echo "==> kind: $KIND"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim_field "$raw_line")"
  [[ -z "$line" ]] && continue
  [[ "${line#\#}" != "$line" ]] && continue

  IFS=$'\t' read -r col1 col2 col3 col4 col5 _extra <<< "$raw_line"
  col1="$(trim_field "$col1")"
  col2="$(trim_field "$col2")"
  col3="$(trim_field "$col3")"
  col4="$(trim_field "$col4")"
  col5="$(trim_field "$col5")"

  if [[ -n "$col5" ]]; then
    run_kind="$col1"
    format="$col2"
    sample="$col3"
    input_path="$col4"
    metadata_enabled="$col5"
  else
    run_kind="smoke"
    format="$col1"
    sample="$col2"
    input_path="$col3"
    metadata_enabled="$col4"
  fi

  if [[ -z "$run_kind" || -z "$format" || -z "$sample" || -z "$input_path" || -z "$metadata_enabled" ]]; then
    echo "skip malformed benchmark row: $raw_line" >&2
    continue
  fi

  if ! is_supported_kind "$run_kind" || [[ "$run_kind" == "all" ]]; then
    echo "unknown run_kind in corpus: $run_kind" >&2
    exit 1
  fi

  if ! should_run_kind "$KIND" "$run_kind"; then
    continue
  fi

  metadata_json="$(json_bool "$metadata_enabled")"
  input_abs="$(resolve_input_path "$input_path")"
  file_size="$(file_size_bytes "$input_abs")"
  if [[ "$WARMUP" -gt 0 ]]; then
    for ((warmup_iteration = 1; warmup_iteration <= WARMUP; warmup_iteration++)); do
      sample_dir="$BENCH_ROOT/$format/$sample/warmup-$warmup_iteration"
      output_md="$sample_dir/$sample.md"
      rm -rf "$sample_dir"
      mkdir -p "$sample_dir"

      cmd=(moon run "$ROOT/cli" -- normal "$input_abs" "$output_md")
      if [[ "$metadata_json" == "true" ]]; then
        cmd=(moon run "$ROOT/cli" -- normal --with-metadata "$input_abs" "$output_md")
      fi

      echo "==> warmup $format/$sample #$warmup_iteration"
      "${cmd[@]}" >/dev/null 2>&1 || true
    done
  fi

  for iteration in $(seq 1 "$ITERATIONS"); do
    sample_dir="$BENCH_ROOT/$format/$sample/iter-$iteration"
    output_md="$sample_dir/$sample.md"
    rm -rf "$sample_dir"
    mkdir -p "$sample_dir"

    cmd=(moon run "$ROOT/cli" -- normal "$input_abs" "$output_md")
    if [[ "$metadata_json" == "true" ]]; then
      cmd=(moon run "$ROOT/cli" -- normal --with-metadata "$input_abs" "$output_md")
    fi

    echo "==> benchmark $format/$sample iter-$iteration"
    set_now_ms
    started_ms="$NOW_MS_VALUE"
    start_precision="$TIMER_PRECISION"
    if "${cmd[@]}" >/dev/null 2>&1; then
      exit_status=0
    else
      exit_status=$?
    fi
    set_now_ms
    ended_ms="$NOW_MS_VALUE"
    end_precision="$TIMER_PRECISION"

    elapsed_ms=$((ended_ms - started_ms))
    if (( elapsed_ms < 0 )); then
      elapsed_ms=0
    fi

    if [[ "$start_precision" == "$end_precision" ]]; then
      timer_precision="$end_precision"
    else
      timer_precision="mixed"
    fi

    output_bytes="$(file_size_bytes "$output_md")"
    asset_count="$(count_assets "$sample_dir")"
    timestamp="$(timestamp_utc)"

    printf '{' >> "$RESULTS_PATH"
    printf '"runner":"%s",' "$(json_escape "markitdown-mb")" >> "$RESULTS_PATH"
    printf '"mode":"%s",' "$(json_escape "normal")" >> "$RESULTS_PATH"
    printf '"run_kind":"%s",' "$(json_escape "$run_kind")" >> "$RESULTS_PATH"
    printf '"format":"%s",' "$(json_escape "$format")" >> "$RESULTS_PATH"
    printf '"sample":"%s",' "$(json_escape "$sample")" >> "$RESULTS_PATH"
    printf '"input_path":"%s",' "$(json_escape "$input_path")" >> "$RESULTS_PATH"
    printf '"file_size":%s,' "$file_size" >> "$RESULTS_PATH"
    printf '"metadata_enabled":%s,' "$metadata_json" >> "$RESULTS_PATH"
    printf '"iteration":%s,' "$iteration" >> "$RESULTS_PATH"
    printf '"warmup":false,' >> "$RESULTS_PATH"
    printf '"elapsed_ms":%s,' "$elapsed_ms" >> "$RESULTS_PATH"
    printf '"output_bytes":%s,' "$output_bytes" >> "$RESULTS_PATH"
    printf '"asset_count":%s,' "$asset_count" >> "$RESULTS_PATH"
    printf '"exit_status":%s,' "$exit_status" >> "$RESULTS_PATH"
    printf '"timestamp":"%s",' "$(json_escape "$timestamp")" >> "$RESULTS_PATH"
    printf '"git_rev":"%s",' "$(json_escape "$GIT_REV")" >> "$RESULTS_PATH"
    printf '"tmp_root":"%s",' "$(json_escape "$TMP_ROOT")" >> "$RESULTS_PATH"
    printf '"timer_precision":"%s"' "$(json_escape "$timer_precision")" >> "$RESULTS_PATH"
    printf '}\n' >> "$RESULTS_PATH"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$format" \
      "$sample" \
      "$iteration" \
      "$exit_status" \
      "$elapsed_ms" \
      "$output_bytes" \
      "$asset_count" \
      >> "$RUNS_TSV_PATH"

    run_count=$((run_count + 1))
    if [[ "$exit_status" -ne 0 ]]; then
      fail_count=$((fail_count + 1))
    fi
  done
done < "$CORPUS_PATH"

generate_summary

echo "==> benchmark results: $RESULTS_PATH"
echo "==> benchmark summary: $SUMMARY_PATH"
echo "==> samples run: $run_count"
echo "==> failures: $fail_count"

if [[ "$run_count" -eq 0 ]]; then
  echo "no benchmark rows executed" >&2
  exit 1
fi

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
