#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
BENCH_ROOT="$TMP_ROOT/bench/batch_profile"
CORPUS_PATH="$ROOT/samples/benchmark/corpus.tsv"
RESULTS_PATH="$BENCH_ROOT/results.jsonl"
GROUP_RUNS_TSV_PATH="$BENCH_ROOT/.group_runs.tsv"
FILE_RESULTS_TSV_PATH="$BENCH_ROOT/file_results.tsv"
STARTUP_TSV_PATH="$BENCH_ROOT/startup.tsv"
SUMMARY_PATH="$BENCH_ROOT/summary.tsv"
STARTUP_SUMMARY_PATH="$BENCH_ROOT/startup-summary.tsv"
COMPARISON_SUMMARY_PATH="$BENCH_ROOT/comparison-summary.tsv"
ITERATIONS="${BATCH_PROFILE_ITERATIONS:-${BENCH_ITERATIONS:-1}}"
WARMUP="${BATCH_PROFILE_WARMUP:-${BENCH_WARMUP:-0}}"
FORMATS_RAW="${BATCH_PROFILE_FORMATS:-csv,json,html,xlsx,docx,pdf}"
GROUP_SIZES_RAW="${BATCH_PROFILE_GROUP_SIZES:-${BATCH_PROFILE_COUNTS:-1,3,8,16}}"
MODELS_RAW="${BATCH_PROFILE_MODELS:-both}"
METADATA_MODES_RAW="${BATCH_PROFILE_METADATA_MODES:-}"
LEGACY_METADATA_MODE_RAW="${BATCH_PROFILE_METADATA:-${BATCH_PROFILE_WITH_METADATA:-}}"
MEMORY_PROBE_MODE="${BATCH_PROFILE_MEMORY:-auto}"
STARTUP_PROBE_ITERATIONS="${BATCH_PROFILE_STARTUP_ITERS:-3}"
TIME_MODE="none"
TIME_LABEL="none"
TIME_SUPPORTED="false"
MB_VERSION=""
MB_RUNNER_KIND="unknown"
MB_PREBUILT_CLI="$ROOT/_build/native/debug/build/cli/cli.exe"
WITH_METADATA_JSON="false"
WITH_METADATA_FLAG="false"
CURRENT_METADATA_MODE_LABEL="without-metadata"
declare -a MB_BASE_CMD=()

json_escape() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

trim_field() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

lower_field() {
  printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]'
}

json_bool() {
  local raw
  raw="$(lower_field "${1-}")"
  case "$raw" in
    true|1|yes)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

is_trueish() {
  [[ "$(json_bool "${1-}")" == "true" ]]
}

is_non_negative_int() {
  [[ "${1-}" =~ ^[0-9]+$ ]]
}

timestamp_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

git_rev() {
  git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || true
}

set_now_ms() {
  local raw
  raw="$(date +%s%N 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ ${#raw} -gt 10 ]]; then
    NOW_MS_VALUE="$((raw / 1000000))"
    NOW_MS_PRECISION="ms"
    return
  fi

  raw="$(LC_ALL=C LANG=C perl -MTime::HiRes=time -e 'print int(time()*1000), qq(\n)' 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    NOW_MS_VALUE="$raw"
    NOW_MS_PRECISION="ms"
    return
  fi

  raw="$(date +%s 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    NOW_MS_VALUE="$((raw * 1000))"
    NOW_MS_PRECISION="s"
    return
  fi

  NOW_MS_VALUE="0"
  NOW_MS_PRECISION="unknown"
}

file_size_bytes() {
  local path="${1-}"
  if [[ -f "$path" ]]; then
    wc -c < "$path" | tr -d '[:space:]'
  else
    printf '0'
  fi
}

input_ext_with_dot() {
  local path="${1-}"
  local base="${path##*/}"
  if [[ "$base" == *.* ]]; then
    printf '.%s' "${base##*.}"
  else
    printf ''
  fi
}

sanitize_name() {
  printf '%s' "${1-}" | tr -c '[:alnum:]_-' '-'
}

pad_index() {
  local n="${1-0}"
  printf '%03d' "$n"
}

sum_manifest_input_bytes() {
  local manifest_path="${1-}"
  awk -F '\t' 'NR > 1 { sum += $4 + 0 } END { print sum + 0 }' "$manifest_path"
}

median_from_column() {
  local path="${1-}"
  local column="${2-1}"
  awk -F '\t' -v column="$column" '
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
    {
      value = $column + 0
      values[++count] = value
    }
    END {
      if (count == 0) {
        print 0
        exit
      }
      sort_numeric(values, count)
      if (count % 2 == 1) {
        print format_metric(values[(count + 1) / 2])
      } else {
        lower = count / 2
        upper = lower + 1
        print format_metric((values[lower] + values[upper]) / 2.0)
      }
    }
  ' "$path"
}

mode_label_from_flag() {
  if is_trueish "${1-}"; then
    printf 'with-metadata'
  else
    printf 'without-metadata'
  fi
}

parse_metadata_modes() {
  local raw="$1"
  METADATA_MODE_VALUES=()

  if [[ -z "$raw" ]]; then
    METADATA_MODE_VALUES=("0" "1")
    return
  fi

  raw="$(lower_field "$(trim_field "$raw")")"
  case "$raw" in
    both|all)
      METADATA_MODE_VALUES=("0" "1")
      return
      ;;
  esac

  IFS=',' read -r -a _parts <<< "$raw"
  for part in "${_parts[@]}"; do
    part="$(lower_field "$(trim_field "$part")")"
    case "$part" in
      0|false|no|off|without-metadata|without_metadata)
        METADATA_MODE_VALUES+=("0")
        ;;
      1|true|yes|on|with-metadata|with_metadata)
        METADATA_MODE_VALUES+=("1")
        ;;
      "")
        ;;
      *)
        echo "unknown metadata mode: $part" >&2
        exit 1
        ;;
    esac
  done

  if [[ "${#METADATA_MODE_VALUES[@]}" -eq 0 ]]; then
    echo "no metadata modes selected" >&2
    exit 1
  fi
}

usage() {
  cat <<EOF
usage: ./samples/scripts/bench_batch_profile.sh [--formats csv,json,...] [--group-sizes 1,3,8,16] [--models MODELS] [--iterations N] [--warmup N]

Environment overrides:
  BATCH_PROFILE_ITERATIONS   measured iterations per group (default: 1)
  BATCH_PROFILE_WARMUP       unrecorded warmup runs per group (default: 0)
  BENCH_ITERATIONS           legacy alias for iterations
  BENCH_WARMUP               legacy alias for warmup
  MARKITDOWN_TMP_DIR         override temp root (default: \$ROOT/.tmp)
  BATCH_PROFILE_FORMATS      comma-separated formats (default: csv,json,html,xlsx,docx,pdf)
  BATCH_PROFILE_GROUP_SIZES  comma-separated file counts (default: 1,3,8,16)
  BATCH_PROFILE_COUNTS       legacy alias for group sizes
  BATCH_PROFILE_MODELS       both | process-per-file | single-process-batch
  BATCH_PROFILE_METADATA_MODES metadata modes: 0,1 | both | without-metadata,with-metadata
  BATCH_PROFILE_METADATA     legacy single-mode alias: 0 | 1
  BATCH_PROFILE_WITH_METADATA legacy single-mode alias: 0 | 1
  BATCH_PROFILE_MEMORY       auto | off | required
  BATCH_PROFILE_STARTUP_ITERS startup probe iterations (default: 3)

Notes:
  * This harness is additive. It does not replace smoke or comparison baselines.
  * It reuses smoke-corpus inputs without changing checked-in corpus files.
  * It compares repeated single-file normal conversion against one batch command.
  * Large group sizes may repeat representative samples to measure batch overhead and throughput.
  * Memory probing is optional and platform-dependent:
    - Linux: /usr/bin/time -v
    - macOS/BSD: /usr/bin/time -l
EOF
}

resolve_mb_runner() {
  if [[ -x "$MB_PREBUILT_CLI" ]]; then
    MB_BASE_CMD=("$MB_PREBUILT_CLI")
    MB_RUNNER_KIND="prebuilt-native"
    return
  fi

  MB_BASE_CMD=("moon" "run" "$ROOT/cli" "--")
  MB_RUNNER_KIND="moon-run"
}

detect_time_probe() {
  TIME_MODE="none"
  TIME_LABEL="none"
  TIME_SUPPORTED="false"

  if [[ "$MEMORY_PROBE_MODE" == "off" ]]; then
    return
  fi

  local probe_dir="$BENCH_ROOT/time_probe"
  mkdir -p "$probe_dir"

  if /usr/bin/time -v -o "$probe_dir/linux.txt" true >/dev/null 2>&1; then
    if grep -q "Maximum resident set size" "$probe_dir/linux.txt"; then
      TIME_MODE="linux-v"
      TIME_LABEL="/usr/bin/time -v"
      TIME_SUPPORTED="true"
      return
    fi
  fi

  if /usr/bin/time -l -o "$probe_dir/bsd.txt" true >/dev/null 2>&1; then
    if grep -q "maximum resident set size" "$probe_dir/bsd.txt"; then
      TIME_MODE="bsd-l"
      TIME_LABEL="/usr/bin/time -l"
      TIME_SUPPORTED="true"
      return
    fi
  fi

  if [[ "$MEMORY_PROBE_MODE" == "required" ]]; then
    echo "memory probe requested but no supported /usr/bin/time mode was detected" >&2
    exit 1
  fi
}

parse_peak_rss_bytes() {
  local time_path="${1-}"
  if [[ ! -s "$time_path" ]]; then
    printf ''
    return
  fi

  case "$TIME_MODE" in
    linux-v)
      awk -F ':' '
        /Maximum resident set size/ {
          gsub(/[[:space:]]+/, "", $2)
          if ($2 ~ /^[0-9]+$/) {
            print ($2 + 0) * 1024
          }
          exit
        }
      ' "$time_path"
      ;;
    bsd-l)
      awk '
        /maximum resident set size/ {
          if ($1 ~ /^[0-9]+$/) {
            print $1 + 0
          }
          exit
        }
      ' "$time_path"
      ;;
    *)
      printf ''
      ;;
  esac
}

parse_peak_footprint_bytes() {
  local time_path="${1-}"
  if [[ "$TIME_MODE" != "bsd-l" ]] || [[ ! -s "$time_path" ]]; then
    printf ''
    return
  fi

  awk '
    /peak memory footprint/ {
      if ($1 ~ /^[0-9]+$/) {
        print $1 + 0
      }
      exit
    }
  ' "$time_path"
}

run_with_optional_time() {
  local time_path="$1"
  local stdout_path="$2"
  local stderr_path="$3"
  shift 3

  mkdir -p "$(dirname "$stdout_path")" "$(dirname "$stderr_path")"
  : > "$stdout_path"
  : > "$stderr_path"
  : > "$time_path"

  case "$TIME_MODE" in
    linux-v)
      /usr/bin/time -v -o "$time_path" "$@" >"$stdout_path" 2>"$stderr_path"
      ;;
    bsd-l)
      /usr/bin/time -l -o "$time_path" "$@" >"$stdout_path" 2>"$stderr_path"
      ;;
    *)
      "$@" >"$stdout_path" 2>"$stderr_path"
      ;;
  esac
}

write_json_result() {
  local model="$1"
  local format="$2"
  local file_count="$3"
  local iteration="$4"
  local runner_kind="$5"
  local runner_command="$6"
  local input_bytes="$7"
  local output_bytes="$8"
  local success_count="$9"
  local failure_count="${10}"
  local elapsed_ms="${11}"
  local median_file_ms="${12}"
  local throughput_files_per_sec="${13}"
  local throughput_input_bytes_per_sec="${14}"
  local peak_rss_bytes="${15}"
  local peak_footprint_bytes="${16}"
  local fixed_overhead_ms="${17}"
  local process_startup_total_ms="${18}"
  local process_startup_per_file_ms="${19}"
  local startup_probe_ms="${20}"
  local startup_probe_kind="${21}"
  local timestamp="${22}"
  local git_revision="${23}"

  printf '{' >> "$RESULTS_PATH"
  printf '"model":"%s",' "$(json_escape "$model")" >> "$RESULTS_PATH"
  printf '"format":"%s",' "$(json_escape "$format")" >> "$RESULTS_PATH"
  printf '"file_count":%s,' "$file_count" >> "$RESULTS_PATH"
  printf '"iteration":%s,' "$iteration" >> "$RESULTS_PATH"
  printf '"runner_kind":"%s",' "$(json_escape "$runner_kind")" >> "$RESULTS_PATH"
  printf '"runner_command":"%s",' "$(json_escape "$runner_command")" >> "$RESULTS_PATH"
  printf '"input_bytes":%s,' "$input_bytes" >> "$RESULTS_PATH"
  printf '"output_bytes":%s,' "$output_bytes" >> "$RESULTS_PATH"
  printf '"success_count":%s,' "$success_count" >> "$RESULTS_PATH"
  printf '"failure_count":%s,' "$failure_count" >> "$RESULTS_PATH"
  printf '"elapsed_ms":%s,' "$elapsed_ms" >> "$RESULTS_PATH"
  printf '"median_file_ms":%s,' "$median_file_ms" >> "$RESULTS_PATH"
  printf '"throughput_files_per_sec":%s,' "$throughput_files_per_sec" >> "$RESULTS_PATH"
  printf '"throughput_input_bytes_per_sec":%s,' "$throughput_input_bytes_per_sec" >> "$RESULTS_PATH"
  printf '"peak_rss_bytes":%s,' "${peak_rss_bytes:-0}" >> "$RESULTS_PATH"
  printf '"peak_footprint_bytes":%s,' "${peak_footprint_bytes:-0}" >> "$RESULTS_PATH"
  printf '"fixed_overhead_ms":%s,' "${fixed_overhead_ms:-0}" >> "$RESULTS_PATH"
  printf '"estimated_process_overhead_total_ms":%s,' "${process_startup_total_ms:-0}" >> "$RESULTS_PATH"
  printf '"estimated_process_overhead_per_file_ms":%s,' "${process_startup_per_file_ms:-0}" >> "$RESULTS_PATH"
  printf '"startup_probe_ms":%s,' "${startup_probe_ms:-0}" >> "$RESULTS_PATH"
  printf '"startup_probe_kind":"%s",' "$(json_escape "$startup_probe_kind")" >> "$RESULTS_PATH"
  printf '"with_metadata":%s,' "$WITH_METADATA_JSON" >> "$RESULTS_PATH"
  printf '"metadata_mode":"%s",' "$(json_escape "$CURRENT_METADATA_MODE_LABEL")" >> "$RESULTS_PATH"
  printf '"timestamp":"%s",' "$(json_escape "$timestamp")" >> "$RESULTS_PATH"
  printf '"git_rev":"%s",' "$(json_escape "$git_revision")" >> "$RESULTS_PATH"
  printf '"memory_probe":"%s"' "$(json_escape "$TIME_LABEL")" >> "$RESULTS_PATH"
  printf '}\n' >> "$RESULTS_PATH"
}

generate_group_summary() {
  if [[ ! -s "$GROUP_RUNS_TSV_PATH" ]]; then
    printf 'model\tformat\tfile_count\tmetadata_enabled\tmetadata_mode\truns\tfailed\tmedian_elapsed_ms\tavg_elapsed_ms\tmedian_files_per_sec\tmedian_input_bytes_per_sec\tmedian_peak_rss_bytes\tmedian_fixed_overhead_ms\tmedian_estimated_process_overhead_per_file_ms\n' \
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
      if (n == 0) {
        return "0"
      }
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
      print "model", "format", "file_count", "metadata_enabled", "metadata_mode", "runs", "failed", "median_elapsed_ms", "avg_elapsed_ms", "median_files_per_sec", "median_input_bytes_per_sec", "median_peak_rss_bytes", "median_fixed_overhead_ms", "median_estimated_process_overhead_per_file_ms"
    }
    NR == 1 {
      next
    }
    {
      key = $1 SUBSEP $2 SUBSEP $3 SUBSEP $4
      if (!(key in seen)) {
        seen[key] = 1
        order[++order_count] = key
        models[key] = $1
        formats[key] = $2
        counts[key] = $3
        metadata_enabled[key] = $4
        metadata_mode[key] = $5
      }

      runs[key]++
      if ($8 + 0 != 0) {
        failed[key]++
      }
      elapsed[key] = elapsed[key] (elapsed[key] == "" ? "" : " ") ($9 + 0)
      files_per_sec[key] = files_per_sec[key] (files_per_sec[key] == "" ? "" : " ") ($13 + 0)
      input_bytes_per_sec[key] = input_bytes_per_sec[key] (input_bytes_per_sec[key] == "" ? "" : " ") ($14 + 0)
      peak_rss[key] = peak_rss[key] (peak_rss[key] == "" ? "" : " ") ($15 + 0)
      fixed_overhead[key] = fixed_overhead[key] (fixed_overhead[key] == "" ? "" : " ") ($17 + 0)
      startup_per_file[key] = startup_per_file[key] (startup_per_file[key] == "" ? "" : " ") ($19 + 0)
      sum_elapsed[key] += $9 + 0
    }
    END {
      for (i = 1; i <= order_count; i++) {
        key = order[i]
        avg_elapsed = sum_elapsed[key] / runs[key]
        print models[key], formats[key], counts[key], metadata_enabled[key], metadata_mode[key], runs[key], failed[key] + 0, median_of(elapsed[key]), format_metric(avg_elapsed), median_of(files_per_sec[key]), median_of(input_bytes_per_sec[key]), median_of(peak_rss[key]), median_of(fixed_overhead[key]), median_of(startup_per_file[key])
      }
    }
  ' "$GROUP_RUNS_TSV_PATH" > "$SUMMARY_PATH"
}

generate_startup_summary() {
  if [[ ! -s "$STARTUP_TSV_PATH" ]]; then
    printf 'probe\truns\tmedian_elapsed_ms\tmedian_peak_rss_bytes\n' > "$STARTUP_SUMMARY_PATH"
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
      if (n == 0) {
        return "0"
      }
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
      print "probe", "runs", "median_elapsed_ms", "median_peak_rss_bytes"
    }
    NR == 1 {
      next
    }
    {
      probe = $1
      runs[probe]++
      elapsed[probe] = elapsed[probe] (elapsed[probe] == "" ? "" : " ") ($2 + 0)
      peak[probe] = peak[probe] (peak[probe] == "" ? "" : " ") ($3 + 0)
      if (!(probe in seen)) {
        order[++count] = probe
        seen[probe] = 1
      }
    }
    END {
      for (i = 1; i <= count; i++) {
        probe = order[i]
        print probe, runs[probe], median_of(elapsed[probe]), median_of(peak[probe])
      }
    }
  ' "$STARTUP_TSV_PATH" > "$STARTUP_SUMMARY_PATH"
}

generate_comparison_summary() {
  if [[ ! -s "$GROUP_RUNS_TSV_PATH" ]]; then
    printf 'format\tgroup_size\tmetadata_enabled\tmetadata_mode\tprocess_per_file_ms\tsingle_process_batch_ms\tspeedup\ttotal_input_bytes\ttotal_output_bytes\tavg_ms_per_file_process\tavg_ms_per_file_batch\tpeak_rss_kb_process\tpeak_rss_kb_batch\trss_delta_kb\tfailure_count\n' \
      > "$COMPARISON_SUMMARY_PATH"
    return
  fi

  awk -F '\t' '
    function format_metric(value) {
      if (value == int(value)) {
        return sprintf("%d", int(value))
      }
      return sprintf("%.2f", value)
    }
    BEGIN {
      OFS = "\t"
      print "format", "group_size", "metadata_enabled", "metadata_mode", "process_per_file_ms", "single_process_batch_ms", "speedup", "total_input_bytes", "total_output_bytes", "avg_ms_per_file_process", "avg_ms_per_file_batch", "peak_rss_kb_process", "peak_rss_kb_batch", "rss_delta_kb", "failure_count"
    }
    NR == 1 {
      next
    }
    {
      key = $2 SUBSEP $3 SUBSEP $4
      format = $2
      group_size = $3
      metadata_enabled = $4
      metadata_mode = $5
      failure = $8 + 0
      elapsed = $9 + 0
      input_bytes = $10 + 0
      output_bytes = $11 + 0
      peak_rss_bytes = $15 + 0

      formats[key] = format
      group_sizes[key] = group_size
      metadata_enableds[key] = metadata_enabled
      metadata_modes[key] = metadata_mode
      inputs[key] = input_bytes
      outputs[key] = output_bytes

      if (!seen[key]++) {
        order[++count] = key
      }

      if ($1 == "process-per-file") {
        process_elapsed[key] = elapsed
        process_failure[key] = failure
        process_peak_kb[key] = int(peak_rss_bytes / 1024)
      } else if ($1 == "single-process-batch") {
        batch_elapsed[key] = elapsed
        batch_failure[key] = failure
        batch_peak_kb[key] = int(peak_rss_bytes / 1024)
      }
    }
    END {
      for (i = 1; i <= count; i++) {
        key = order[i]
        p = process_elapsed[key] + 0
        b = batch_elapsed[key] + 0
        g = group_sizes[key] + 0
        speedup = 0
        avg_p = 0
        avg_b = 0
        if (p > 0 && b > 0) {
          speedup = p / b
        }
        if (g > 0) {
          avg_p = p / g
          avg_b = b / g
        }
        rss_p = process_peak_kb[key] + 0
        rss_b = batch_peak_kb[key] + 0
        rss_delta = rss_b - rss_p
        failure_count = process_failure[key] + batch_failure[key]
        print formats[key], group_sizes[key], metadata_enableds[key], metadata_modes[key], p, b, format_metric(speedup), inputs[key], outputs[key], format_metric(avg_p), format_metric(avg_b), rss_p, rss_b, rss_delta, failure_count
      }
    }
  ' "$GROUP_RUNS_TSV_PATH" > "$COMPARISON_SUMMARY_PATH"
}

collect_group_manifest() {
  local format="$1"
  local file_count="$2"
  local manifest_path="$3"
  local matched=0

  printf 'index\tsample\tinput_abs\tinput_bytes\tstaged_name\n' > "$manifest_path"
  local sample_pool_path="${manifest_path}.pool"
  : > "$sample_pool_path"

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    local line
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
      row_format="$col2"
      sample="$col3"
      input_path="$col4"
      metadata_enabled="$col5"
    else
      run_kind="smoke"
      row_format="$col1"
      sample="$col2"
      input_path="$col3"
      metadata_enabled="$col4"
    fi

    if [[ "$(lower_field "$run_kind")" != "smoke" ]]; then
      continue
    fi
    if [[ "$(lower_field "$row_format")" != "$(lower_field "$format")" ]]; then
      continue
    fi
    if [[ "$(json_bool "$metadata_enabled")" != "false" ]]; then
      continue
    fi

    matched=$((matched + 1))

    local input_abs="$ROOT/$input_path"
    if [[ "$input_path" == /* ]]; then
      input_abs="$input_path"
    fi
    local ext
    ext="$(input_ext_with_dot "$input_abs")"
    local staged_name
    staged_name="$(pad_index "$matched")-$(sanitize_name "$sample")$ext"
    local input_bytes
    input_bytes="$(file_size_bytes "$input_abs")"

    printf '%s\t%s\t%s\t%s\t%s\n' \
      "0" \
      "$sample" \
      "$input_abs" \
      "$input_bytes" \
      "$staged_name" \
      >> "$sample_pool_path"
  done < "$CORPUS_PATH"

  local pool_count
  pool_count="$(awk 'END { print NR + 0 }' "$sample_pool_path")"
  if [[ "$pool_count" -eq 0 ]]; then
    rm -f "$sample_pool_path"
    return 1
  fi

  local index=1
  while [[ "$index" -le "$file_count" ]]; do
    local pool_row_index=$(( ((index - 1) % pool_count) + 1 ))
    local pool_row
    pool_row="$(sed -n "${pool_row_index}p" "$sample_pool_path")"
    local _zero sample input_abs input_bytes staged_name
    IFS=$'\t' read -r _zero sample input_abs input_bytes staged_name <<< "$pool_row"
    local ext
    ext="$(input_ext_with_dot "$input_abs")"
    local repeated_tag=""
    if [[ "$index" -gt "$pool_count" ]]; then
      repeated_tag="-r$(( ((index - 1) / pool_count) + 1 ))"
    fi
    local final_staged_name
    final_staged_name="$(pad_index "$index")-$(sanitize_name "$sample")${repeated_tag}${ext}"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$index" \
      "$sample" \
      "$input_abs" \
      "$input_bytes" \
      "$final_staged_name" \
      >> "$manifest_path"
    index=$((index + 1))
  done

  rm -f "$sample_pool_path"
  return 0
}

stage_manifest_inputs() {
  local manifest_path="$1"
  local input_dir="$2"
  mkdir -p "$input_dir"
  while IFS=$'\t' read -r _index _sample input_abs _bytes staged_name; do
    [[ -z "$staged_name" ]] && continue
    ln -sf "$input_abs" "$input_dir/$staged_name"
  done < <(tail -n +2 "$manifest_path")
}

record_startup_probe() {
  local probe_name="$1"
  shift

  local timestamp
  local git_revision
  git_revision="$(git_rev)"

  for iteration in $(seq 1 "$STARTUP_PROBE_ITERATIONS"); do
    local probe_root="$BENCH_ROOT/startup/$probe_name/iter-$iteration"
    local stdout_path="$probe_root/stdout.txt"
    local stderr_path="$probe_root/stderr.txt"
    local time_path="$probe_root/time.txt"
    mkdir -p "$probe_root"

    set_now_ms
    local started_ms="$NOW_MS_VALUE"
    local exit_status=0
    if run_with_optional_time "$time_path" "$stdout_path" "$stderr_path" "$@"; then
      exit_status=0
    else
      exit_status=$?
    fi
    set_now_ms
    local ended_ms="$NOW_MS_VALUE"
    local elapsed_ms=$((ended_ms - started_ms))
    if (( elapsed_ms < 0 )); then
      elapsed_ms=0
    fi

    local peak_rss_bytes
    local peak_footprint_bytes
    peak_rss_bytes="$(parse_peak_rss_bytes "$time_path")"
    peak_footprint_bytes="$(parse_peak_footprint_bytes "$time_path")"
    timestamp="$(timestamp_utc)"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$probe_name" \
      "$elapsed_ms" \
      "${peak_rss_bytes:-0}" \
      "${peak_footprint_bytes:-0}" \
      "$exit_status" \
      "$iteration" \
      "$timestamp" \
      "$git_revision" \
      >> "$STARTUP_TSV_PATH"
  done
}

extract_startup_probe_median() {
  local probe_name="$1"
  awk -F '\t' -v probe="$probe_name" '
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
    NR == 1 {
      next
    }
    $1 == probe {
      values[++count] = $2 + 0
    }
    END {
      if (count == 0) {
        print 0
        exit
      }
      sort_numeric(values, count)
      if (count % 2 == 1) {
        print format_metric(values[(count + 1) / 2])
      } else {
        lower = count / 2
        upper = lower + 1
        print format_metric((values[lower] + values[upper]) / 2.0)
      }
    }
  ' "$STARTUP_TSV_PATH"
}

run_process_per_file_group() {
  local format="$1"
  local file_count="$2"
  local iteration="$3"
  local manifest_path="$4"
  local group_root="$5"

  local sample_root="$group_root/process-per-file"
  mkdir -p "$sample_root"
  local temp_metrics="$sample_root/.file_metrics.tsv"
  : > "$temp_metrics"

  set_now_ms
  local group_started_ms="$NOW_MS_VALUE"
  local success_count=0
  local failure_count=0
  local total_output_bytes=0
  local max_peak_rss_bytes=0
  local max_peak_footprint_bytes=0
  local runner_command="${MB_BASE_CMD[*]} normal"

  while IFS=$'\t' read -r index sample input_abs input_bytes staged_name; do
    [[ -z "$sample" ]] && continue
    local sample_dir="$sample_root/$sample"
    local output_md="$sample_dir/$sample.md"
    local stdout_path="$sample_dir/stdout.txt"
    local stderr_path="$sample_dir/stderr.txt"
    local time_path="$sample_dir/time.txt"
    mkdir -p "$sample_dir"

    local -a cmd=("${MB_BASE_CMD[@]}" "normal")
    if [[ "$WITH_METADATA_FLAG" == "true" ]]; then
      cmd+=("--with-metadata")
    fi
    cmd+=("$input_abs" "$output_md")

    set_now_ms
    local started_ms="$NOW_MS_VALUE"
    if run_with_optional_time "$time_path" "$stdout_path" "$stderr_path" "${cmd[@]}"; then
      exit_status=0
    else
      exit_status=$?
    fi
    set_now_ms
    local ended_ms="$NOW_MS_VALUE"
    local elapsed_ms=$((ended_ms - started_ms))
    if (( elapsed_ms < 0 )); then
      elapsed_ms=0
    fi

    local output_bytes
    output_bytes="$(file_size_bytes "$output_md")"
    local peak_rss_bytes
    peak_rss_bytes="$(parse_peak_rss_bytes "$time_path")"
    local peak_footprint_bytes
    peak_footprint_bytes="$(parse_peak_footprint_bytes "$time_path")"
    local status="ok"
    if [[ "$exit_status" -ne 0 ]]; then
      status="failed"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$index" \
      "$sample" \
      "$input_abs" \
      "$input_bytes" \
      "$output_md" \
      "$output_bytes" \
      "$elapsed_ms" \
      "${peak_rss_bytes:-0}" \
      "${peak_footprint_bytes:-0}" \
      "$exit_status" \
      >> "$temp_metrics"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "process-per-file" \
      "$format" \
      "$file_count" \
      "$iteration" \
      "$sample" \
      "$input_abs" \
      "$input_bytes" \
      "$output_md" \
      "$output_bytes" \
      "$elapsed_ms" \
      "${peak_rss_bytes:-0}" \
      "${peak_footprint_bytes:-0}" \
      "process" \
      "$status" \
      "$exit_status" \
      >> "$FILE_RESULTS_TSV_PATH"
  done < <(tail -n +2 "$manifest_path")

  set_now_ms
  local group_ended_ms="$NOW_MS_VALUE"
  PROCESS_TOTAL_ELAPSED_MS=$((group_ended_ms - group_started_ms))
  if (( PROCESS_TOTAL_ELAPSED_MS < 0 )); then
    PROCESS_TOTAL_ELAPSED_MS=0
  fi

  while IFS=$'\t' read -r _index _sample _input_abs _input_bytes _output_md output_bytes _elapsed_ms peak_rss_bytes peak_footprint_bytes exit_status; do
    total_output_bytes=$((total_output_bytes + output_bytes))
    if [[ "$exit_status" -eq 0 ]]; then
      success_count=$((success_count + 1))
    else
      failure_count=$((failure_count + 1))
    fi
    if (( peak_rss_bytes > max_peak_rss_bytes )); then
      max_peak_rss_bytes="$peak_rss_bytes"
    fi
    if (( peak_footprint_bytes > max_peak_footprint_bytes )); then
      max_peak_footprint_bytes="$peak_footprint_bytes"
    fi
  done < "$temp_metrics"

  PROCESS_SUCCESS_COUNT="$success_count"
  PROCESS_FAILURE_COUNT="$failure_count"
  PROCESS_TOTAL_OUTPUT_BYTES="$total_output_bytes"
  PROCESS_MAX_PEAK_RSS_BYTES="$max_peak_rss_bytes"
  PROCESS_MAX_PEAK_FOOTPRINT_BYTES="$max_peak_footprint_bytes"
  PROCESS_MEDIAN_FILE_MS="$(median_from_column "$temp_metrics" 7)"
  PROCESS_FILES_PER_SEC="$(awk -v files="$file_count" -v elapsed="$PROCESS_TOTAL_ELAPSED_MS" 'BEGIN { if (elapsed <= 0) { print 0 } else { printf "%.3f", (files * 1000.0) / elapsed } }')"
  local total_input_bytes
  total_input_bytes="$(sum_manifest_input_bytes "$manifest_path")"
  PROCESS_INPUT_BYTES_PER_SEC="$(awk -v bytes="$total_input_bytes" -v elapsed="$PROCESS_TOTAL_ELAPSED_MS" 'BEGIN { if (elapsed <= 0) { print 0 } else { printf "%.1f", (bytes * 1000.0) / elapsed } }')"
  PROCESS_RUNNER_COMMAND="$runner_command"
}

run_single_process_batch_group() {
  local format="$1"
  local file_count="$2"
  local iteration="$3"
  local manifest_path="$4"
  local group_root="$5"

  local sample_root="$group_root/single-process-batch"
  local input_dir="$sample_root/input"
  local output_dir="$sample_root/output"
  local stdout_path="$sample_root/stdout.txt"
  local stderr_path="$sample_root/stderr.txt"
  local time_path="$sample_root/time.txt"
  mkdir -p "$sample_root"
  stage_manifest_inputs "$manifest_path" "$input_dir"

  local -a cmd=("${MB_BASE_CMD[@]}" "batch")
  if [[ "$WITH_METADATA_FLAG" == "true" ]]; then
    cmd+=("--with-metadata")
  fi
  cmd+=("$input_dir" "$output_dir")

  set_now_ms
  local group_started_ms="$NOW_MS_VALUE"
  if run_with_optional_time "$time_path" "$stdout_path" "$stderr_path" "${cmd[@]}"; then
    BATCH_EXIT_STATUS=0
  else
    BATCH_EXIT_STATUS=$?
  fi
  set_now_ms
  local group_ended_ms="$NOW_MS_VALUE"
  BATCH_TOTAL_ELAPSED_MS=$((group_ended_ms - group_started_ms))
  if (( BATCH_TOTAL_ELAPSED_MS < 0 )); then
    BATCH_TOTAL_ELAPSED_MS=0
  fi

  local summary_path="$output_dir/batch-summary.tsv"
  local temp_metrics="$sample_root/.file_metrics.tsv"
  : > "$temp_metrics"
  local total_output_bytes=0
  local success_count=0
  local failure_count=0
  local internal_elapsed_sum=0
  local peak_rss_bytes
  peak_rss_bytes="$(parse_peak_rss_bytes "$time_path")"
  local peak_footprint_bytes
  peak_footprint_bytes="$(parse_peak_footprint_bytes "$time_path")"

  if [[ -f "$summary_path" ]]; then
    while IFS=$'\t' read -r index input_path output_md row_format status elapsed_ms error; do
      [[ -z "$index" ]] && continue
      local output_bytes
      output_bytes="$(file_size_bytes "$output_md")"
      local staged_base
      staged_base="${input_path##*/}"
      local manifest_row
      manifest_row="$(awk -F '\t' -v staged="$staged_base" 'NR > 1 && $5 == staged { print $0; exit }' "$manifest_path")"
      local manifest_sample=""
      local manifest_input_abs="$input_path"
      local manifest_input_bytes="0"
      if [[ -n "$manifest_row" ]]; then
        IFS=$'\t' read -r _m_index manifest_sample manifest_input_abs manifest_input_bytes _m_staged <<< "$manifest_row"
      fi

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$index" \
        "$manifest_sample" \
        "$manifest_input_abs" \
        "$manifest_input_bytes" \
        "$output_md" \
        "$row_format" \
        "$status" \
        "$elapsed_ms" \
        "$output_bytes" \
        "${peak_rss_bytes:-0}" \
        "${peak_footprint_bytes:-0}" \
        >> "$temp_metrics"
    done < <(tail -n +2 "$summary_path")
  fi

  while IFS=$'\t' read -r _index sample_name input_path input_bytes output_md row_format status elapsed_ms output_bytes row_peak_rss row_peak_footprint; do
    [[ -z "$sample_name" ]] && continue
    total_output_bytes=$((total_output_bytes + output_bytes))
    internal_elapsed_sum=$((internal_elapsed_sum + elapsed_ms))
    if [[ "$status" == "ok" ]]; then
      success_count=$((success_count + 1))
    else
      failure_count=$((failure_count + 1))
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "single-process-batch" \
      "$format" \
      "$file_count" \
      "$iteration" \
      "$sample_name" \
      "$input_path" \
      "$input_bytes" \
      "$output_md" \
      "$output_bytes" \
      "$elapsed_ms" \
      "$row_peak_rss" \
      "$row_peak_footprint" \
      "group_peak_repeated" \
      "$status" \
      "$BATCH_EXIT_STATUS" \
      >> "$FILE_RESULTS_TSV_PATH"
  done < "$temp_metrics"

  BATCH_SUCCESS_COUNT="$success_count"
  BATCH_FAILURE_COUNT="$failure_count"
  BATCH_TOTAL_OUTPUT_BYTES="$total_output_bytes"
  BATCH_INTERNAL_ELAPSED_SUM="$internal_elapsed_sum"
  BATCH_MEDIAN_FILE_MS="$(median_from_column "$temp_metrics" 8)"
  local total_input_bytes
  total_input_bytes="$(sum_manifest_input_bytes "$manifest_path")"
  BATCH_FILES_PER_SEC="$(awk -v files="$file_count" -v elapsed="$BATCH_TOTAL_ELAPSED_MS" 'BEGIN { if (elapsed <= 0) { print 0 } else { printf "%.3f", (files * 1000.0) / elapsed } }')"
  BATCH_INPUT_BYTES_PER_SEC="$(awk -v bytes="$total_input_bytes" -v elapsed="$BATCH_TOTAL_ELAPSED_MS" 'BEGIN { if (elapsed <= 0) { print 0 } else { printf "%.1f", (bytes * 1000.0) / elapsed } }')"
  BATCH_FIXED_OVERHEAD_MS=$((BATCH_TOTAL_ELAPSED_MS - BATCH_INTERNAL_ELAPSED_SUM))
  if (( BATCH_FIXED_OVERHEAD_MS < 0 )); then
    BATCH_FIXED_OVERHEAD_MS=0
  fi
  BATCH_PEAK_RSS_BYTES="${peak_rss_bytes:-0}"
  BATCH_PEAK_FOOTPRINT_BYTES="${peak_footprint_bytes:-0}"
  BATCH_RUNNER_COMMAND="${MB_BASE_CMD[*]} batch"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --formats)
      [[ $# -lt 2 ]] && {
        echo "missing value for --formats" >&2
        usage >&2
        exit 1
      }
      FORMATS_RAW="$2"
      shift 2
      ;;
    --group-sizes|--counts)
      [[ $# -lt 2 ]] && {
        echo "missing value for --group-sizes" >&2
        usage >&2
        exit 1
      }
      GROUP_SIZES_RAW="$2"
      shift 2
      ;;
    --models)
      [[ $# -lt 2 ]] && {
        echo "missing value for --models" >&2
        usage >&2
        exit 1
      }
      MODELS_RAW="$2"
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
    --memory)
      [[ $# -lt 2 ]] && {
        echo "missing value for --memory" >&2
        usage >&2
        exit 1
      }
      MEMORY_PROBE_MODE="$2"
      shift 2
      ;;
    --metadata-modes)
      [[ $# -lt 2 ]] && {
        echo "missing value for --metadata-modes" >&2
        usage >&2
        exit 1
      }
      METADATA_MODES_RAW="$2"
      shift 2
      ;;
    --with-metadata)
      METADATA_MODES_RAW="1"
      shift
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

if ! is_non_negative_int "$ITERATIONS" || [[ "$ITERATIONS" -eq 0 ]]; then
  echo "BENCH_ITERATIONS/--iterations must be a positive integer" >&2
  exit 1
fi

if ! is_non_negative_int "$WARMUP"; then
  echo "BENCH_WARMUP/--warmup must be a non-negative integer" >&2
  exit 1
fi

if ! is_non_negative_int "$STARTUP_PROBE_ITERATIONS" || [[ "$STARTUP_PROBE_ITERATIONS" -eq 0 ]]; then
  echo "BATCH_PROFILE_STARTUP_ITERS must be a positive integer" >&2
  exit 1
fi

if [[ ! -f "$CORPUS_PATH" ]]; then
  echo "benchmark corpus missing: $CORPUS_PATH" >&2
  exit 1
fi

case "$MODELS_RAW" in
  both|process-per-file|single-process-batch)
    ;;
  *)
    echo "BATCH_PROFILE_MODELS/--models must be one of: both, process-per-file, single-process-batch" >&2
    exit 1
    ;;
esac

case "$MEMORY_PROBE_MODE" in
  auto|off|required)
    ;;
  *)
    echo "BATCH_PROFILE_MEMORY/--memory must be one of: auto, off, required" >&2
    exit 1
    ;;
esac

if [[ -z "$METADATA_MODES_RAW" && -n "$LEGACY_METADATA_MODE_RAW" ]]; then
  METADATA_MODES_RAW="$LEGACY_METADATA_MODE_RAW"
fi
parse_metadata_modes "$METADATA_MODES_RAW"

IFS=',' read -r -a FORMATS <<< "$FORMATS_RAW"
IFS=',' read -r -a COUNTS <<< "$GROUP_SIZES_RAW"
for i in "${!FORMATS[@]}"; do
  FORMATS[$i]="$(trim_field "${FORMATS[$i]}")"
done
for i in "${!COUNTS[@]}"; do
  COUNTS[$i]="$(trim_field "${COUNTS[$i]}")"
done

FORMATS_FILTERED=()
for format in "${FORMATS[@]}"; do
  [[ -z "$format" ]] && continue
  FORMATS_FILTERED+=("$format")
done
COUNTS_FILTERED=()
for count in "${COUNTS[@]}"; do
  [[ -z "$count" ]] && continue
  COUNTS_FILTERED+=("$count")
done
FORMATS=("${FORMATS_FILTERED[@]}")
COUNTS=("${COUNTS_FILTERED[@]}")

if [[ "${#FORMATS[@]}" -eq 0 ]]; then
  echo "no formats selected" >&2
  exit 1
fi
if [[ "${#COUNTS[@]}" -eq 0 ]]; then
  echo "no file counts selected" >&2
  exit 1
fi
for count in "${COUNTS[@]}"; do
  if ! is_non_negative_int "$count" || [[ "$count" -eq 0 ]]; then
    echo "invalid file count: $count" >&2
    exit 1
  fi
done

echo "==> warming Moon build"
if ! (cd "$ROOT" && moon build >/dev/null); then
  echo "moon build failed" >&2
  exit 1
fi

resolve_mb_runner
detect_time_probe

rm -rf "$BENCH_ROOT"
mkdir -p "$BENCH_ROOT"
: > "$RESULTS_PATH"
printf 'model\tformat\tfile_count\titeration\tsample\tinput_path\tinput_bytes\toutput_md\toutput_bytes\telapsed_ms\tpeak_rss_bytes\tpeak_footprint_bytes\tmemory_scope\tstatus\texit_status\n' > "$FILE_RESULTS_TSV_PATH"
printf 'probe\telapsed_ms\tpeak_rss_bytes\tpeak_footprint_bytes\texit_status\titeration\ttimestamp\tgit_rev\n' > "$STARTUP_TSV_PATH"
printf 'model\tformat\tfile_count\tmetadata_enabled\tmetadata_mode\titeration\trunner_kind\tfailure_count\telapsed_ms\tinput_bytes\toutput_bytes\tsuccess_count\tthroughput_files_per_sec\tthroughput_input_bytes_per_sec\tpeak_rss_bytes\tpeak_footprint_bytes\tfixed_overhead_ms\testimated_process_overhead_total_ms\testimated_process_overhead_per_file_ms\tmedian_file_ms\tstartup_probe_ms\tstartup_probe_kind\n' > "$GROUP_RUNS_TSV_PATH"

GIT_REV="$(git_rev)"
MB_VERSION="markitdown-mb@${GIT_REV:-unknown}"

echo "==> runner kind: $MB_RUNNER_KIND"
echo "==> runner base: ${MB_BASE_CMD[*]}"
echo "==> formats: ${FORMATS[*]}"
echo "==> counts: ${COUNTS[*]}"
echo "==> metadata modes: ${METADATA_MODE_VALUES[*]}"
echo "==> models: $MODELS_RAW"
echo "==> iterations: $ITERATIONS"
echo "==> warmup: $WARMUP"
echo "==> memory probe: $TIME_LABEL"

record_startup_probe "help" "${MB_BASE_CMD[@]}" "--help"
empty_probe_input="$BENCH_ROOT/startup/empty-batch/input"
empty_probe_output="$BENCH_ROOT/startup/empty-batch/output"
mkdir -p "$empty_probe_input"
record_startup_probe "empty-batch" "${MB_BASE_CMD[@]}" "batch" "$empty_probe_input" "$empty_probe_output"
HELP_STARTUP_MEDIAN_MS="$(extract_startup_probe_median "help")"
EMPTY_BATCH_STARTUP_MEDIAN_MS="$(extract_startup_probe_median "empty-batch")"

run_count=0
fail_count=0
skipped_count=0

for metadata_value in "${METADATA_MODE_VALUES[@]}"; do
  WITH_METADATA_JSON="$(json_bool "$metadata_value")"
  WITH_METADATA_FLAG="false"
  if [[ "$WITH_METADATA_JSON" == "true" ]]; then
    WITH_METADATA_FLAG="true"
  fi
  CURRENT_METADATA_MODE_LABEL="$(mode_label_from_flag "$metadata_value")"

  for format in "${FORMATS[@]}"; do
    for file_count in "${COUNTS[@]}"; do
      manifest_path="$BENCH_ROOT/manifests/${CURRENT_METADATA_MODE_LABEL}/${format}-${file_count}.tsv"
      mkdir -p "$(dirname "$manifest_path")"
      if ! collect_group_manifest "$format" "$file_count" "$manifest_path"; then
        echo "==> skip $format/$file_count/$CURRENT_METADATA_MODE_LABEL: no usable smoke-corpus rows" >&2
        skipped_count=$((skipped_count + 1))
        continue
      fi

      total_input_bytes="$(sum_manifest_input_bytes "$manifest_path")"

      if [[ "$WARMUP" -gt 0 ]]; then
        for warmup_iteration in $(seq 1 "$WARMUP"); do
          warmup_root="$BENCH_ROOT/warmup/${CURRENT_METADATA_MODE_LABEL}/${format}/${file_count}/iter-$warmup_iteration"
          rm -rf "$warmup_root"
          mkdir -p "$warmup_root"
          if [[ "$MODELS_RAW" == "both" || "$MODELS_RAW" == "process-per-file" ]]; then
            run_process_per_file_group "$format" "$file_count" "$warmup_iteration" "$manifest_path" "$warmup_root" >/dev/null 2>&1 || true
          fi
          if [[ "$MODELS_RAW" == "both" || "$MODELS_RAW" == "single-process-batch" ]]; then
            run_single_process_batch_group "$format" "$file_count" "$warmup_iteration" "$manifest_path" "$warmup_root" >/dev/null 2>&1 || true
          fi
        done
      fi

      for iteration in $(seq 1 "$ITERATIONS"); do
        group_root="$BENCH_ROOT/groups/${CURRENT_METADATA_MODE_LABEL}/${format}/${file_count}/iter-$iteration"
        rm -rf "$group_root"
        mkdir -p "$group_root"
        timestamp="$(timestamp_utc)"

        process_est_total_ms=""
        process_est_per_file_ms=""

        if [[ "$MODELS_RAW" == "both" || "$MODELS_RAW" == "process-per-file" ]]; then
          echo "==> benchmark process-per-file/$CURRENT_METADATA_MODE_LABEL/$format/$file_count iter-$iteration"
          run_process_per_file_group "$format" "$file_count" "$iteration" "$manifest_path" "$group_root"
        fi

        if [[ "$MODELS_RAW" == "both" || "$MODELS_RAW" == "single-process-batch" ]]; then
          echo "==> benchmark single-process-batch/$CURRENT_METADATA_MODE_LABEL/$format/$file_count iter-$iteration"
          run_single_process_batch_group "$format" "$file_count" "$iteration" "$manifest_path" "$group_root"
        fi

        if [[ "$MODELS_RAW" == "both" ]]; then
          process_est_total_ms=$((PROCESS_TOTAL_ELAPSED_MS - BATCH_INTERNAL_ELAPSED_SUM))
          if (( process_est_total_ms < 0 )); then
            process_est_total_ms=0
          fi
          process_est_per_file_ms="$(awk -v total="$process_est_total_ms" -v files="$file_count" 'BEGIN { if (files <= 0) { print 0 } else { printf "%.1f", total / files } }')"
        fi

        if [[ "$MODELS_RAW" == "both" || "$MODELS_RAW" == "process-per-file" ]]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "process-per-file" \
          "$format" \
          "$file_count" \
          "$WITH_METADATA_JSON" \
          "$CURRENT_METADATA_MODE_LABEL" \
          "$iteration" \
          "$MB_RUNNER_KIND" \
          "$PROCESS_FAILURE_COUNT" \
          "$PROCESS_TOTAL_ELAPSED_MS" \
          "$total_input_bytes" \
          "$PROCESS_TOTAL_OUTPUT_BYTES" \
          "$PROCESS_SUCCESS_COUNT" \
          "$PROCESS_FILES_PER_SEC" \
          "$PROCESS_INPUT_BYTES_PER_SEC" \
          "$PROCESS_MAX_PEAK_RSS_BYTES" \
          "$PROCESS_MAX_PEAK_FOOTPRINT_BYTES" \
          "" \
          "${process_est_total_ms:-}" \
          "${process_est_per_file_ms:-}" \
          "$PROCESS_MEDIAN_FILE_MS" \
          "$HELP_STARTUP_MEDIAN_MS" \
          "help" \
          >> "$GROUP_RUNS_TSV_PATH"

        write_json_result \
          "process-per-file" \
          "$format" \
          "$file_count" \
          "$iteration" \
          "$MB_RUNNER_KIND" \
          "$PROCESS_RUNNER_COMMAND" \
          "$total_input_bytes" \
          "$PROCESS_TOTAL_OUTPUT_BYTES" \
          "$PROCESS_SUCCESS_COUNT" \
          "$PROCESS_FAILURE_COUNT" \
          "$PROCESS_TOTAL_ELAPSED_MS" \
          "$PROCESS_MEDIAN_FILE_MS" \
          "$PROCESS_FILES_PER_SEC" \
          "$PROCESS_INPUT_BYTES_PER_SEC" \
          "$PROCESS_MAX_PEAK_RSS_BYTES" \
          "$PROCESS_MAX_PEAK_FOOTPRINT_BYTES" \
          "" \
          "${process_est_total_ms:-0}" \
          "${process_est_per_file_ms:-0}" \
          "$HELP_STARTUP_MEDIAN_MS" \
          "help" \
          "$timestamp" \
          "$GIT_REV"

        run_count=$((run_count + 1))
        if [[ "$PROCESS_FAILURE_COUNT" -ne 0 ]]; then
          fail_count=$((fail_count + 1))
        fi
        fi

        if [[ "$MODELS_RAW" == "both" || "$MODELS_RAW" == "single-process-batch" ]]; then
          printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "single-process-batch" \
          "$format" \
          "$file_count" \
          "$WITH_METADATA_JSON" \
          "$CURRENT_METADATA_MODE_LABEL" \
          "$iteration" \
          "$MB_RUNNER_KIND" \
          "$BATCH_FAILURE_COUNT" \
          "$BATCH_TOTAL_ELAPSED_MS" \
          "$total_input_bytes" \
          "$BATCH_TOTAL_OUTPUT_BYTES" \
          "$BATCH_SUCCESS_COUNT" \
          "$BATCH_FILES_PER_SEC" \
          "$BATCH_INPUT_BYTES_PER_SEC" \
          "$BATCH_PEAK_RSS_BYTES" \
          "$BATCH_PEAK_FOOTPRINT_BYTES" \
          "$BATCH_FIXED_OVERHEAD_MS" \
          "" \
          "" \
          "$BATCH_MEDIAN_FILE_MS" \
          "$EMPTY_BATCH_STARTUP_MEDIAN_MS" \
          "empty-batch" \
          >> "$GROUP_RUNS_TSV_PATH"

        write_json_result \
          "single-process-batch" \
          "$format" \
          "$file_count" \
          "$iteration" \
          "$MB_RUNNER_KIND" \
          "$BATCH_RUNNER_COMMAND" \
          "$total_input_bytes" \
          "$BATCH_TOTAL_OUTPUT_BYTES" \
          "$BATCH_SUCCESS_COUNT" \
          "$BATCH_FAILURE_COUNT" \
          "$BATCH_TOTAL_ELAPSED_MS" \
          "$BATCH_MEDIAN_FILE_MS" \
          "$BATCH_FILES_PER_SEC" \
          "$BATCH_INPUT_BYTES_PER_SEC" \
          "$BATCH_PEAK_RSS_BYTES" \
          "$BATCH_PEAK_FOOTPRINT_BYTES" \
          "$BATCH_FIXED_OVERHEAD_MS" \
          "" \
          "" \
          "$EMPTY_BATCH_STARTUP_MEDIAN_MS" \
          "empty-batch" \
          "$timestamp" \
          "$GIT_REV"

        run_count=$((run_count + 1))
        if [[ "$BATCH_FAILURE_COUNT" -ne 0 || "$BATCH_EXIT_STATUS" -ne 0 ]]; then
          fail_count=$((fail_count + 1))
        fi
        fi
      done
    done
  done
done

generate_group_summary
generate_startup_summary
generate_comparison_summary

echo "==> batch profiling results: $RESULTS_PATH"
echo "==> batch profiling summary: $SUMMARY_PATH"
echo "==> batch profiling comparison summary: $COMPARISON_SUMMARY_PATH"
echo "==> startup summary: $STARTUP_SUMMARY_PATH"
echo "==> file results: $FILE_RESULTS_TSV_PATH"
echo "==> runs: $run_count"
echo "==> failures: $fail_count"
echo "==> skipped groups: $skipped_count"

if [[ "$run_count" -eq 0 ]]; then
  echo "no batch profiling groups executed" >&2
  exit 1
fi

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
