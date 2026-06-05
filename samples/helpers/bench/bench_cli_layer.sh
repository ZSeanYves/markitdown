#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/bench/bench_v2_common.sh"

TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUTPUT_DIR="$TMP_ROOT/bench/cli"
MANIFEST_PATH=""
MANIFEST_DIR=""
FORMAT_FILTER=""
PROFILE="normal"
ITERATIONS="${BENCH_ITERATIONS:-1}"
WARMUP="${BENCH_WARMUP:-0}"
SUMMARY_PATH="$OUTPUT_DIR/summary.tsv"
RUNS_TSV_PATH="$OUTPUT_DIR/summary.runs.tsv"
WORK_ROOT="$OUTPUT_DIR/work"
RUNNER_KIND="unknown"
RUNNER_CLASS="unknown"
RUNNER_LABEL="unknown"
PUBLISHABLE="true"
NOW_MS_VALUE="0"
TIMER_PRECISION="unknown"
declare -A MANIFEST_FIELD_INDEX=()
declare -a RUNNER_CMD=()

usage() {
  cat <<'EOF'
usage: ./samples/bench.sh --layer cli [--manifest PATH] [--format fmt[,fmt]] [--iterations N] [--warmup N] [--output-dir DIR] [--profile normal|cold-start|batch]

Notes:
  * CLI layer rows come only from quality-lab external_bench/MANIFEST.tsv.
  * normal and cold-start profiles run one native CLI process per measured iteration:
      normal <input> <output.md>
  * batch profile fails closed in this phase because the stable batch CLI contract is not selected yet.
  * Build the native CLI first or set MARKITDOWN_CLI.
EOF
}

set_output_dir() {
  OUTPUT_DIR="$1"
  SUMMARY_PATH="$OUTPUT_DIR/summary.tsv"
  RUNS_TSV_PATH="$OUTPUT_DIR/summary.runs.tsv"
  WORK_ROOT="$OUTPUT_DIR/work"
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

tsv_escape() {
  local value="${1-}"
  value="${value//$'\t'/ }"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  printf '%s' "$value"
}

sanitize_component() {
  printf '%s' "${1-}" | tr -c '[:alnum:]_-' '-'
}

is_non_negative_int() {
  [[ "${1-}" =~ ^[0-9]+$ ]]
}

file_size_bytes() {
  local path="${1-}"
  if [[ -f "$path" ]]; then
    wc -c < "$path" | tr -d '[:space:]'
  else
    printf '0'
  fi
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

  raw="$(date +%s 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    TIMER_PRECISION="s"
    NOW_MS_VALUE="$((raw * 1000))"
    return
  fi

  TIMER_PRECISION="unknown"
  NOW_MS_VALUE="0"
}

resolve_manifest_path() {
  if [[ -n "$MANIFEST_PATH" ]]; then
    if [[ ! -f "$MANIFEST_PATH" ]]; then
      echo "external_bench manifest missing: $MANIFEST_PATH" >&2
      bench_v2_fail_missing_manifest
      exit 1
    fi
  elif ! MANIFEST_PATH="$(bench_v2_resolve_manifest "$ROOT")"; then
    bench_v2_fail_missing_manifest
    exit 1
  fi

  bench_v2_require_external_bench_header "$MANIFEST_PATH"
  MANIFEST_DIR="$(bench_v2_manifest_dir "$MANIFEST_PATH")"
}

parse_manifest_header() {
  local raw_line line header
  header=""
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(trim_field "${raw_line//$'\r'/}")"
    [[ -z "$line" ]] && continue
    [[ "${line#\#}" != "$line" ]] && continue
    header="$raw_line"
    break
  done < "$MANIFEST_PATH"

  if [[ -z "$header" ]]; then
    echo "external_bench manifest is empty: $MANIFEST_PATH" >&2
    exit 1
  fi

  local -a header_fields=()
  local i key required
  IFS=$'\t' read -r -a header_fields <<< "$header"
  MANIFEST_FIELD_INDEX=()
  for i in "${!header_fields[@]}"; do
    key="$(lower_field "$(trim_field "${header_fields[$i]}")")"
    [[ -z "$key" ]] && continue
    MANIFEST_FIELD_INDEX["$key"]="$i"
  done

  for required in bench_id format rel_path size_class bench_layers enabled_tier; do
    if [[ -z "${MANIFEST_FIELD_INDEX[$required]+set}" ]]; then
      echo "external_bench manifest missing required field: $required" >&2
      exit 1
    fi
  done
}

manifest_field() {
  local name="$1"
  local -n row_ref="$2"
  if [[ -z "${MANIFEST_FIELD_INDEX[$name]+set}" ]]; then
    printf ''
    return
  fi
  local index="${MANIFEST_FIELD_INDEX[$name]}"
  trim_field "${row_ref[$index]-}"
}

split_tsv_fields() {
  local line="$1"
  local -n out_ref="$2"
  local sentinel=$'\037'
  local encoded
  local last
  encoded="${line//$'\t'/$sentinel}"
  encoded="${encoded}${sentinel}_"
  IFS="$sentinel" read -r -a out_ref <<< "$encoded"
  last=$((${#out_ref[@]} - 1))
  unset "out_ref[$last]"
}

format_filter_matches() {
  local format="$(lower_field "$(trim_field "${1-}")")"
  [[ -z "$FORMAT_FILTER" ]] && return 0
  bench_v2_list_contains_token "$FORMAT_FILTER" "$format"
}

resolve_cli_runner() {
  local candidate resolved
  if [[ -n "${MARKITDOWN_CLI:-}" ]]; then
    if [[ -x "$MARKITDOWN_CLI" ]]; then
      resolved="$MARKITDOWN_CLI"
    elif command -v "$MARKITDOWN_CLI" >/dev/null 2>&1; then
      resolved="$(command -v "$MARKITDOWN_CLI")"
    else
      echo "MARKITDOWN_CLI is not executable: $MARKITDOWN_CLI" >&2
      exit 1
    fi
    RUNNER_CMD=("$resolved")
    RUNNER_KIND="markitdown-cli-env"
    RUNNER_CLASS="user-override"
    RUNNER_LABEL="$resolved"
    PUBLISHABLE="true"
    return
  fi

  while IFS= read -r candidate; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    RUNNER_CMD=("$candidate")
    RUNNER_KIND="prebuilt-native"
    RUNNER_CLASS="native-binary"
    RUNNER_LABEL="$candidate"
    PUBLISHABLE="true"
    return
  done < <(find "$ROOT/_build/native" -path "*/cli/*.exe" -type f 2>/dev/null | sort)

  if [[ "${MARKITDOWN_BENCH_ALLOW_MOON_RUN:-}" == "1" ]]; then
    RUNNER_CMD=("moon" "run" "$ROOT/cli" "--")
    RUNNER_KIND="moon-run"
    RUNNER_CLASS="moon-run-fallback"
    RUNNER_LABEL="moon run $ROOT/cli --"
    PUBLISHABLE="false"
    return
  fi

  echo "build native CLI first or set MARKITDOWN_CLI" >&2
  exit 1
}

run_cli_row() {
  local bench_id="$1"
  local format="$2"
  local input_abs="$3"
  local source_group="$4"
  local size_class="$5"
  local input_bytes="$6"
  local safe_id notes total iter measured_iter iter_dir output_md stderr_path stdout_path
  local started_ms ended_ms elapsed_ms exit_status output_bytes stderr_bytes

  safe_id="$(sanitize_component "$bench_id")"
  notes="entrypoint=cli-normal process_per_iteration=true profile=$PROFILE"
  if [[ "$PROFILE" == "cold-start" ]]; then
    notes="$notes cold_start_process_per_iteration=true"
  fi
  if [[ "$PUBLISHABLE" == "false" ]]; then
    notes="$notes not_publishable_baseline"
  fi

  total=$((ITERATIONS + WARMUP))
  for ((iter = 1; iter <= total; iter++)); do
    if (( iter <= WARMUP )); then
      iter_dir="$WORK_ROOT/$PROFILE/$safe_id/warmup-$iter"
      measured_iter=0
    else
      measured_iter=$((iter - WARMUP))
      iter_dir="$WORK_ROOT/$PROFILE/$safe_id/iter-$measured_iter"
    fi

    rm -rf "$iter_dir"
    mkdir -p "$iter_dir"
    output_md="$iter_dir/output.md"
    stderr_path="$iter_dir/stderr.txt"
    stdout_path="$iter_dir/stdout.txt"

    set_now_ms
    started_ms="$NOW_MS_VALUE"
    if "${RUNNER_CMD[@]}" normal "$input_abs" "$output_md" >"$stdout_path" 2>"$stderr_path"; then
      exit_status=0
    else
      exit_status=$?
    fi
    set_now_ms
    ended_ms="$NOW_MS_VALUE"
    elapsed_ms=$((ended_ms - started_ms))
    if (( elapsed_ms < 0 )); then
      elapsed_ms=0
    fi

    if (( iter <= WARMUP )); then
      continue
    fi

    output_bytes="$(file_size_bytes "$output_md")"
    stderr_bytes="$(file_size_bytes "$stderr_path")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "cli" \
      "$(tsv_escape "$PROFILE")" \
      "$(tsv_escape "$RUNNER_LABEL")" \
      "$(tsv_escape "$format")" \
      "$(tsv_escape "$bench_id")" \
      "$(tsv_escape "$source_group")" \
      "$(tsv_escape "$size_class")" \
      "$measured_iter" \
      "$exit_status" \
      "$elapsed_ms" \
      "$input_bytes" \
      "$output_bytes" \
      "$stderr_bytes" \
      "$(tsv_escape "$RUNNER_KIND")" \
      "$(tsv_escape "$RUNNER_CLASS")" \
      "$PUBLISHABLE" \
      "$(tsv_escape "$notes")" \
      >> "$RUNS_TSV_PATH"
  done
}

generate_summary() {
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

    function metric(value) {
      if (value == int(value)) {
        return sprintf("%d", int(value))
      }
      return sprintf("%.1f", value)
    }

    function percentile(list, pct,    n, values, idx) {
      n = split(list, values, " ")
      sort_numeric(values, n)
      idx = int((n * pct + 99) / 100)
      if (idx < 1) {
        idx = 1
      }
      if (idx > n) {
        idx = n
      }
      return metric(values[idx] + 0)
    }

    BEGIN {
      OFS = "\t"
      print "layer", "profile", "runner", "format", "sample", "source_group", "size_class", "iterations", "failed", "min_ms", "p50_ms", "p95_ms", "max_ms", "avg_ms", "input_bytes", "output_bytes_last", "stderr_bytes_last", "runner_kind", "runner_class", "publishable", "notes"
    }

    NR == 1 {
      next
    }

    {
      key = $1 SUBSEP $2 SUBSEP $3 SUBSEP $4 SUBSEP $5 SUBSEP $6 SUBSEP $7 SUBSEP $14 SUBSEP $15 SUBSEP $16 SUBSEP $17
      if (!(key in seen)) {
        seen[key] = 1
        order[++order_count] = key
        layer[key] = $1
        profile[key] = $2
        runner[key] = $3
        format[key] = $4
        sample[key] = $5
        source_group[key] = $6
        size_class[key] = $7
        runner_kind[key] = $14
        runner_class[key] = $15
        publishable[key] = $16
        notes[key] = $17
      }
      iterations[key]++
      if ($9 + 0 != 0) {
        failed[key]++
      }
      elapsed = $10 + 0
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
      input_bytes[key] = $11
      output_bytes_last[key] = $12
      stderr_bytes_last[key] = $13
    }

    END {
      for (i = 1; i <= order_count; i++) {
        key = order[i]
        avg = sum_ms[key] / iterations[key]
        print layer[key], profile[key], runner[key], format[key], sample[key], source_group[key], size_class[key], iterations[key], failed[key] + 0, min_ms[key], percentile(times[key], 50), percentile(times[key], 95), max_ms[key], metric(avg), input_bytes[key], output_bytes_last[key], stderr_bytes_last[key], runner_kind[key], runner_class[key], publishable[key], notes[key]
      }
    }
  ' "$RUNS_TSV_PATH" > "$SUMMARY_PATH"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer)
      [[ $# -ge 2 ]] || { echo "missing value for --layer" >&2; exit 1; }
      if [[ "$2" != "cli" ]]; then
        echo "bench_cli_layer only supports --layer cli" >&2
        exit 1
      fi
      shift 2
      ;;
    --manifest)
      [[ $# -ge 2 ]] || { echo "missing value for --manifest" >&2; exit 1; }
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --format)
      [[ $# -ge 2 ]] || { echo "missing value for --format" >&2; exit 1; }
      bench_v2_require_non_empty_token_filter "$1" "$2" || exit 1
      FORMAT_FILTER="$2"
      shift 2
      ;;
    --iterations)
      [[ $# -ge 2 ]] || { echo "missing value for --iterations" >&2; exit 1; }
      ITERATIONS="$2"
      shift 2
      ;;
    --warmup)
      [[ $# -ge 2 ]] || { echo "missing value for --warmup" >&2; exit 1; }
      WARMUP="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || { echo "missing value for --output-dir" >&2; exit 1; }
      set_output_dir "$2"
      shift 2
      ;;
    --output)
      echo "cli layer writes outputs under an output directory; use --output-dir DIR" >&2
      exit 1
      ;;
    --profile)
      [[ $# -ge 2 ]] || { echo "missing value for --profile" >&2; exit 1; }
      PROFILE="$(lower_field "$(trim_field "$2")")"
      shift 2
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

case "$PROFILE" in
  normal|cold-start)
    ;;
  batch)
    echo "cli batch profile not implemented yet" >&2
    exit 1
    ;;
  *)
    echo "unknown cli profile: $PROFILE" >&2
    exit 1
    ;;
esac

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
parse_manifest_header
resolve_cli_runner

mkdir -p "$OUTPUT_DIR" "$WORK_ROOT"
printf 'layer\tprofile\trunner\tformat\tsample\tsource_group\tsize_class\titeration\texit_status\telapsed_ms\tinput_bytes\toutput_bytes\tstderr_bytes\trunner_kind\trunner_class\tpublishable\tnotes\n' > "$RUNS_TSV_PATH"

selected_rows=0
run_count=0
fail_count=0

echo "==> cli layer benchmark"
echo "profile: $PROFILE"
echo "manifest: $MANIFEST_PATH"
echo "manifest dir: $MANIFEST_DIR"
echo "output dir: $OUTPUT_DIR"
echo "runner: $RUNNER_LABEL"
echo "runner_kind: $RUNNER_KIND"
echo "runner_class: $RUNNER_CLASS"
echo "publishable: $PUBLISHABLE"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim_field "${raw_line//$'\r'/}")"
  [[ -z "$line" ]] && continue
  [[ "${line#\#}" != "$line" ]] && continue

  split_tsv_fields "$raw_line" row_fields
  bench_id="$(manifest_field bench_id row_fields)"
  format="$(lower_field "$(manifest_field format row_fields)")"
  rel_path="$(manifest_field rel_path row_fields)"
  source_group="$(manifest_field source_group row_fields)"
  size_class="$(lower_field "$(manifest_field size_class row_fields)")"
  bench_layers="$(manifest_field bench_layers row_fields)"
  enabled_tier="$(lower_field "$(manifest_field enabled_tier row_fields)")"

  if [[ "$(lower_field "$bench_id")" == "bench_id" ]] &&
    [[ "$format" == "format" ]] &&
    [[ "$(lower_field "$rel_path")" == "rel_path" ]]; then
    continue
  fi

  case "$(bench_v2_enabled_tier_action "$enabled_tier")" in
    run)
      ;;
    skip)
      continue
      ;;
    error)
      echo "external_bench cli row has unsupported enabled_tier '$enabled_tier': $bench_id" >&2
      exit 1
      ;;
  esac

  if ! bench_v2_list_contains_token "$bench_layers" "cli"; then
    continue
  fi
  if ! format_filter_matches "$format"; then
    continue
  fi
  if [[ -z "$bench_id" ]]; then
    echo "external_bench cli row has empty bench_id: $raw_line" >&2
    exit 1
  fi
  if [[ -z "$format" ]]; then
    echo "external_bench cli row has empty format: $bench_id" >&2
    exit 1
  fi
  if [[ -z "$rel_path" ]]; then
    echo "external_bench cli row has empty rel_path: $bench_id" >&2
    exit 1
  fi
  if [[ -z "$size_class" ]]; then
    echo "external_bench cli row has empty size_class: $bench_id" >&2
    exit 1
  fi

  bench_v2_reject_forbidden_path "$ROOT" "$rel_path" || exit 1
  input_abs="$(bench_v2_resolve_rel_path "$MANIFEST_DIR" "$rel_path")"
  bench_v2_reject_forbidden_path "$ROOT" "$input_abs" || exit 1
  if [[ ! -f "$input_abs" ]]; then
    echo "external_bench input missing: $input_abs" >&2
    exit 1
  fi

  selected_rows=$((selected_rows + 1))
  input_bytes="$(file_size_bytes "$input_abs")"
  run_cli_row "$bench_id" "$format" "$input_abs" "$source_group" "$size_class" "$input_bytes"
done < "$MANIFEST_PATH"

if [[ "$selected_rows" -eq 0 ]]; then
  echo "no enabled cli benchmark rows selected from external_bench; check enabled_tier, bench_layers, format, or filters" >&2
  exit 1
fi

generate_summary
run_count="$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$RUNS_TSV_PATH")"
fail_count="$(awk -F '\t' 'NR > 1 && $9 + 0 != 0 { count++ } END { print count + 0 }' "$RUNS_TSV_PATH")"

echo "BENCHMARK SUITE COMPLETED"
echo "- layer: cli"
echo "- profile: $PROFILE"
echo "- result_root: $OUTPUT_DIR"
echo "- summary_tsv: $SUMMARY_PATH"
echo "- raw_runs_tsv: $RUNS_TSV_PATH"
echo "- runs: $run_count"
echo "- failures: $fail_count"

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
