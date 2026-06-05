#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"
source "$ROOT/samples/helpers/shared/validation_helpers.sh"
source "$ROOT/samples/helpers/bench/bench_v2_common.sh"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
COMPARE_ROOT="$TMP_ROOT/bench/compare"
MANIFEST_PATH=""
MANIFEST_DIR=""
FORMAT_FILTER=""
RESULTS_PATH="$COMPARE_ROOT/results.jsonl"
RUNS_TSV_PATH="$COMPARE_ROOT/.runs.tsv"
SUMMARY_PATH="$COMPARE_ROOT/summary.tsv"
PYTHON_ENV_ROOT="$COMPARE_ROOT/python_env"
PYTHON_TMPDIR="$PYTHON_ENV_ROOT/tmp"
PYTHON_CACHE_HOME="$PYTHON_ENV_ROOT/cache"
PYTHON_HOME="$PYTHON_ENV_ROOT/home"
TIMER_PRECISION="unknown"
NOW_MS_VALUE="0"
ITERATIONS="${BENCH_ITERATIONS:-1}"
WARMUP="${BENCH_WARMUP:-0}"
MARKITDOWN_COMPARE_PY_BIN="${MARKITDOWN_COMPARE_PY_BIN:-}"
MARKITDOWN_COMPARE_CMD="${MARKITDOWN_COMPARE_CMD:-}"
MARKITDOWN_MB_CMD="${MARKITDOWN_MB_CMD:-}"
MB_VERSION=""
MB_RUNNER_KIND="unknown"
PYTHON_VERSION="unknown"
declare -A MANIFEST_FIELD_INDEX=()

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

resolve_manifest_rel_path() {
  local path="${1-}"
  bench_v2_resolve_rel_path "$MANIFEST_DIR" "$path"
}

file_size_bytes() {
  local path="${1-}"
  if [[ -f "$path" ]]; then
    wc -c < "$path" | tr -d '[:space:]'
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
usage: ./samples/bench.sh --layer compare [--manifest PATH] [--format fmt[,fmt]] [--iterations N] [--warmup N] [--output-dir DIR]

Environment overrides:
  BENCH_ITERATIONS            number of measured iterations per sample (default: 1)
  BENCH_WARMUP                number of unrecorded warmup runs per sample (default: 0)
  MARKITDOWN_TMP_DIR          override temp root (default: \$ROOT/.tmp)
  MARKITDOWN_MB_CMD           markitdown-mb command prefix, e.g. "_build/native/debug/build/cli/cli.exe normal"
  MARKITDOWN_COMPARE_CMD      python runner command prefix, e.g. "/path/to/markitdown"
  MARKITDOWN_COMPARE_PY_BIN   python executable that can run "python -m markitdown"

Notes:
  * This is an overlap-only benchmark between this repository runner and Microsoft MarkItDown.
  * Corpus rows come only from quality-lab external_bench/MANIFEST.tsv.
  * It does not compare metadata semantics, assets semantics, or Markdown similarity.
  * It does not enable OCR plugins, Azure Document Intelligence, or other optional plugin paths.
  * By default the comparison harness builds once, then prefers the prebuilt native cli binary.
  * If no prebuilt cli binary is available, it falls back to "moon run", which includes wrapper overhead.
  * It does not create or manage a Python virtual environment inside this repository.
EOF
}

set_compare_root() {
  COMPARE_ROOT="$1"
  RESULTS_PATH="$COMPARE_ROOT/results.jsonl"
  RUNS_TSV_PATH="$COMPARE_ROOT/.runs.tsv"
  SUMMARY_PATH="$COMPARE_ROOT/summary.tsv"
  PYTHON_ENV_ROOT="$COMPARE_ROOT/python_env"
  PYTHON_TMPDIR="$PYTHON_ENV_ROOT/tmp"
  PYTHON_CACHE_HOME="$PYTHON_ENV_ROOT/cache"
  PYTHON_HOME="$PYTHON_ENV_ROOT/home"
}

is_non_negative_int() {
  [[ "${1-}" =~ ^[0-9]+$ ]]
}

generate_summary() {
  if [[ ! -s "$RUNS_TSV_PATH" ]]; then
    printf 'runner\tformat\tsample\truns\tfailed\tmin_ms\tmedian_ms\tmax_ms\tavg_ms\toutput_bytes_last\tstderr_bytes_last\n' \
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
      print "runner", "format", "sample", "runs", "failed", "min_ms", "median_ms", "max_ms", "avg_ms", "output_bytes_last", "stderr_bytes_last"
    }

    {
      key = $1 SUBSEP $2 SUBSEP $3
      if (!(key in seen)) {
        seen[key] = 1
        order[++order_count] = key
        runners[key] = $1
        formats[key] = $2
        samples[key] = $3
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
      stderr_last[key] = $7
    }

    END {
      for (i = 1; i <= order_count; i++) {
        key = order[i]
        avg = sum_ms[key] / runs[key]
        print runners[key], formats[key], samples[key], runs[key], failed[key] + 0, min_ms[key], median_of(times[key]), max_ms[key], format_metric(avg), output_last[key], stderr_last[key]
      }
    }
  ' "$RUNS_TSV_PATH" > "$SUMMARY_PATH"
}

split_command_string() {
  local raw="${1-}"
  read -r -a PY_COMPARE_CMD <<< "$raw"
}

split_mb_command_string() {
  local raw="${1-}"
  read -r -a MB_COMPARE_CMD <<< "$raw"
}

python_compare_unavailable() {
  local path_markitdown
  path_markitdown="$(command -v markitdown 2>/dev/null || true)"
  if [[ -z "$path_markitdown" ]]; then
    path_markitdown="<missing>"
  fi
  cat >&2 <<EOF
python MarkItDown runner not found.

Checked:
  MARKITDOWN_COMPARE_CMD=${MARKITDOWN_COMPARE_CMD:-<unset>}
  MARKITDOWN_COMPARE_PY_BIN=${MARKITDOWN_COMPARE_PY_BIN:-<unset>}
  PATH markitdown=$path_markitdown

Install Microsoft MarkItDown into a user-managed environment, for example:
  python -m pip install 'markitdown[all]==0.1.5'

Then rerun using one of:
  install markitdown on PATH
  MARKITDOWN_COMPARE_CMD=/path/to/markitdown ./samples/bench.sh --layer compare
  MARKITDOWN_COMPARE_PY_BIN=/path/to/python ./samples/bench.sh --layer compare

The comparison harness does not create or manage a repository-local .venv.
EOF
}

resolve_python_runner() {
  if [[ -n "$MARKITDOWN_COMPARE_CMD" ]]; then
    split_command_string "$MARKITDOWN_COMPARE_CMD"
    if [[ ${#PY_COMPARE_CMD[@]} -eq 0 ]]; then
      python_compare_unavailable
      exit 1
    fi
    if ! command -v "${PY_COMPARE_CMD[0]}" >/dev/null 2>&1 && [[ ! -x "${PY_COMPARE_CMD[0]}" ]]; then
      python_compare_unavailable
      exit 1
    fi
    return
  fi

  if command -v markitdown >/dev/null 2>&1; then
    PY_COMPARE_CMD=("markitdown")
    return
  fi

  if [[ -n "$MARKITDOWN_COMPARE_PY_BIN" ]]; then
    if [[ ! -x "$MARKITDOWN_COMPARE_PY_BIN" ]]; then
      python_compare_unavailable
      exit 1
    fi
    PY_COMPARE_CMD=("$MARKITDOWN_COMPARE_PY_BIN" "-m" "markitdown")
    return
  fi

  python_compare_unavailable
  exit 1
}

resolve_mb_runner() {
  if [[ -n "$MARKITDOWN_MB_CMD" ]]; then
    split_mb_command_string "$MARKITDOWN_MB_CMD"
    if [[ ${#MB_COMPARE_CMD[@]} -eq 0 ]]; then
      echo "MARKITDOWN_MB_CMD did not produce a runnable command prefix" >&2
      exit 1
    fi
    if ! command -v "${MB_COMPARE_CMD[0]}" >/dev/null 2>&1 && [[ ! -x "${MB_COMPARE_CMD[0]}" ]]; then
      echo "MARKITDOWN_MB_CMD runner not found: ${MB_COMPARE_CMD[0]}" >&2
      exit 1
    fi
    MB_RUNNER_KIND="override"
    return
  fi

  if ! resolve_markitdown_cli; then
    echo "failed to resolve markitdown runner" >&2
    exit 1
  fi

  MB_RUNNER_KIND="$CLI_RUNNER_KIND"
  if [[ -n "${CLI_BIN:-}" ]]; then
    MB_COMPARE_CMD=("$CLI_BIN" "normal")
  else
    MB_COMPARE_CMD=("moon" "run" "$ROOT/cli" "--" "normal")
  fi
}

mb_runner_class() {
  runner_class_for_kind "$1"
}

python_runner_class() {
  if [[ -n "$MARKITDOWN_COMPARE_CMD" || -n "$MARKITDOWN_COMPARE_PY_BIN" ]]; then
    printf 'python-markitdown-user-managed'
  else
    printf 'python-markitdown-path'
  fi
}

external_bench_required() {
  bench_v2_fail_missing_manifest
}

resolve_manifest_path() {
  if [[ -n "$MANIFEST_PATH" ]]; then
    if [[ ! -f "$MANIFEST_PATH" ]]; then
      echo "external_bench manifest missing: $MANIFEST_PATH" >&2
      external_bench_required
      exit 1
    fi
  else
    if ! MANIFEST_PATH="$(bench_v2_resolve_manifest "$ROOT")"; then
      external_bench_required
      exit 1
    fi
  fi

  bench_v2_require_external_bench_header "$MANIFEST_PATH"
  MANIFEST_DIR="$(bench_v2_manifest_dir "$MANIFEST_PATH")"
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

parse_manifest_header() {
  local raw_line line header
  header=""

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(trim_field "$raw_line")"
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
  local i key
  IFS=$'\t' read -r -a header_fields <<< "$header"

  if [[ "$(lower_field "$(trim_field "${header_fields[0]-}")")" == "format" ]] &&
    [[ "$(lower_field "$(trim_field "${header_fields[1]-}")")" == "sample" ]] &&
    [[ "$(lower_field "$(trim_field "${header_fields[2]-}")")" == "input_path" ]]; then
    echo "legacy compare manifest schema is not supported; use quality-lab external_bench/MANIFEST.tsv" >&2
    exit 1
  fi

  MANIFEST_FIELD_INDEX=()
  for i in "${!header_fields[@]}"; do
    key="$(lower_field "$(trim_field "${header_fields[$i]}")")"
    [[ -z "$key" ]] && continue
    MANIFEST_FIELD_INDEX["$key"]="$i"
  done

  local required
  for required in bench_id format rel_path size_class bench_layers enabled_tier; do
    if [[ -z "${MANIFEST_FIELD_INDEX[$required]+set}" ]]; then
      echo "external_bench manifest missing required field: $required" >&2
      exit 1
    fi
  done
}

list_contains_token() {
  bench_v2_list_contains_token "$1" "$2"
}

format_filter_matches() {
  local format="$(lower_field "$(trim_field "${1-}")")"
  [[ -z "$FORMAT_FILTER" ]] && return 0
  bench_v2_list_contains_token "$FORMAT_FILTER" "$format"
}

probe_python_runner() {
  mkdir -p "$PYTHON_TMPDIR" "$PYTHON_CACHE_HOME" "$PYTHON_HOME"
  if ! env \
    -u OPENAI_API_KEY \
    -u OPENAI_BASE_URL \
    -u OPENAI_ORG_ID \
    -u AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT \
    -u AZURE_DOCUMENT_INTELLIGENCE_KEY \
    -u AZURE_OPENAI_API_KEY \
    -u AZURE_OPENAI_ENDPOINT \
    -u AZURE_OPENAI_API_VERSION \
    TMPDIR="$PYTHON_TMPDIR" \
    XDG_CACHE_HOME="$PYTHON_CACHE_HOME" \
    HOME="$PYTHON_HOME" \
    "${PY_COMPARE_CMD[@]}" --help >/dev/null 2>&1; then
    echo "python MarkItDown runner exists but failed its startup probe (--help)." >&2
    python_compare_unavailable
    exit 1
  fi
}

resolve_python_version() {
  local raw
  raw="$(
    env \
      -u OPENAI_API_KEY \
      -u OPENAI_BASE_URL \
      -u OPENAI_ORG_ID \
      -u AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT \
      -u AZURE_DOCUMENT_INTELLIGENCE_KEY \
      -u AZURE_OPENAI_API_KEY \
      -u AZURE_OPENAI_ENDPOINT \
      -u AZURE_OPENAI_API_VERSION \
      TMPDIR="$PYTHON_TMPDIR" \
      XDG_CACHE_HOME="$PYTHON_CACHE_HOME" \
      HOME="$PYTHON_HOME" \
      "${PY_COMPARE_CMD[@]}" --version 2>/dev/null || true
  )"
  raw="$(trim_field "$raw")"
  if [[ -n "$raw" ]]; then
    PYTHON_VERSION="$raw"
  else
    PYTHON_VERSION="unknown"
  fi
}

run_mb() {
  local input_abs="$1"
  local output_md="$2"
  local stderr_path="$3"
  "${MB_COMPARE_CMD[@]}" "$input_abs" "$output_md" >/dev/null 2>"$stderr_path"
}

run_python() {
  local input_abs="$1"
  local output_md="$2"
  local stderr_path="$3"
  env \
    -u OPENAI_API_KEY \
    -u OPENAI_BASE_URL \
    -u OPENAI_ORG_ID \
    -u AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT \
    -u AZURE_DOCUMENT_INTELLIGENCE_KEY \
    -u AZURE_OPENAI_API_KEY \
    -u AZURE_OPENAI_ENDPOINT \
    -u AZURE_OPENAI_API_VERSION \
    TMPDIR="$PYTHON_TMPDIR" \
    XDG_CACHE_HOME="$PYTHON_CACHE_HOME" \
    HOME="$PYTHON_HOME" \
    "${PY_COMPARE_CMD[@]}" "$input_abs" -o "$output_md" >/dev/null 2>"$stderr_path"
}

write_result() {
  local runner="$1"
  local version="$2"
  local format="$3"
  local sample="$4"
  local input_path="$5"
  local file_size="$6"
  local iteration="$7"
  local elapsed_ms="$8"
  local output_bytes="$9"
  local stderr_bytes="${10}"
  local exit_status="${11}"
  local output_path="${12}"
  local stderr_path="${13}"
  local timestamp="${14}"
  local git_revision="${15}"
  local tmp_root="${16}"
  local timer_precision="${17}"
  local source_group="${18-}"
  local size_class="${19-}"
  local bench_profile="${20-}"
  local workload_tags="${21-}"
  local bench_layers="${22-}"
  local enabled_tier="${23-}"
  local runner_kind="unknown"
  local runner_class="unknown"
  local runner_command=""
  local execution_path="compare-overlap"
  local status="success"
  local note=""

  if [[ "$exit_status" -ne 0 ]]; then
    status="fail"
  fi

  if [[ "$runner" == "markitdown-mb" ]]; then
    runner_kind="$MB_RUNNER_KIND"
    runner_class="$(mb_runner_class "$MB_RUNNER_KIND")"
    runner_command="${MB_COMPARE_CMD[*]}"
  else
    runner_kind="python-markitdown"
    runner_class="$(python_runner_class)"
    runner_command="${PY_COMPARE_CMD[*]}"
  fi

  printf '{' >> "$RESULTS_PATH"
  printf '"suite":"%s",' "$(json_escape "compare")" >> "$RESULTS_PATH"
  printf '"runner":"%s",' "$(json_escape "$runner")" >> "$RESULTS_PATH"
  printf '"runner_kind":"%s",' "$(json_escape "$runner_kind")" >> "$RESULTS_PATH"
  printf '"runner_class":"%s",' "$(json_escape "$runner_class")" >> "$RESULTS_PATH"
  printf '"command":"%s",' "$(json_escape "$runner_command")" >> "$RESULTS_PATH"
  printf '"version":"%s",' "$(json_escape "$version")" >> "$RESULTS_PATH"
  printf '"format":"%s",' "$(json_escape "$format")" >> "$RESULTS_PATH"
  printf '"sample":"%s",' "$(json_escape "$sample")" >> "$RESULTS_PATH"
  printf '"bench_id":"%s",' "$(json_escape "$sample")" >> "$RESULTS_PATH"
  printf '"source_group":"%s",' "$(json_escape "$source_group")" >> "$RESULTS_PATH"
  printf '"size_class":"%s",' "$(json_escape "$size_class")" >> "$RESULTS_PATH"
  printf '"bench_profile":"%s",' "$(json_escape "$bench_profile")" >> "$RESULTS_PATH"
  printf '"workload_tags":"%s",' "$(json_escape "$workload_tags")" >> "$RESULTS_PATH"
  printf '"bench_layers":"%s",' "$(json_escape "$bench_layers")" >> "$RESULTS_PATH"
  printf '"enabled_tier":"%s",' "$(json_escape "$enabled_tier")" >> "$RESULTS_PATH"
  printf '"input_path":"%s",' "$(json_escape "$input_path")" >> "$RESULTS_PATH"
  printf '"file_size":%s,' "$file_size" >> "$RESULTS_PATH"
  printf '"input_bytes":%s,' "$file_size" >> "$RESULTS_PATH"
  printf '"execution_path":"%s",' "$(json_escape "$execution_path")" >> "$RESULTS_PATH"
  printf '"ocr_enabled":false,' >> "$RESULTS_PATH"
  printf '"debug_enabled":false,' >> "$RESULTS_PATH"
  printf '"metadata_enabled":false,' >> "$RESULTS_PATH"
  printf '"iteration":%s,' "$iteration" >> "$RESULTS_PATH"
  printf '"warmup":false,' >> "$RESULTS_PATH"
  printf '"elapsed_ms":%s,' "$elapsed_ms" >> "$RESULTS_PATH"
  printf '"output_bytes":%s,' "$output_bytes" >> "$RESULTS_PATH"
  printf '"asset_count":null,' >> "$RESULTS_PATH"
  printf '"peak_rss_kb":null,' >> "$RESULTS_PATH"
  printf '"stderr_bytes":%s,' "$stderr_bytes" >> "$RESULTS_PATH"
  printf '"exit_status":%s,' "$exit_status" >> "$RESULTS_PATH"
  printf '"status":"%s",' "$(json_escape "$status")" >> "$RESULTS_PATH"
  printf '"comparability":"%s",' "$(json_escape "overlap-only")" >> "$RESULTS_PATH"
  if [[ -n "$note" ]]; then
    printf '"note":"%s",' "$(json_escape "$note")" >> "$RESULTS_PATH"
  else
    printf '"note":null,' >> "$RESULTS_PATH"
  fi
  printf '"output_path":"%s",' "$(json_escape "$output_path")" >> "$RESULTS_PATH"
  printf '"stderr_path":"%s",' "$(json_escape "$stderr_path")" >> "$RESULTS_PATH"
  printf '"timestamp":"%s",' "$(json_escape "$timestamp")" >> "$RESULTS_PATH"
  printf '"git_rev":"%s",' "$(json_escape "$git_revision")" >> "$RESULTS_PATH"
  printf '"tmp_root":"%s",' "$(json_escape "$tmp_root")" >> "$RESULTS_PATH"
  printf '"timer_precision":"%s"' "$(json_escape "$timer_precision")" >> "$RESULTS_PATH"
  printf '}\n' >> "$RESULTS_PATH"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --layer)
      [[ $# -lt 2 ]] && {
        echo "missing value for --layer" >&2
        usage >&2
        exit 1
      }
      if [[ "$2" != "compare" ]]; then
        echo "bench_compare_markitdown only supports --layer compare" >&2
        exit 1
      fi
      shift 2
      ;;
    --manifest)
      [[ $# -lt 2 ]] && {
        echo "missing value for --manifest" >&2
        usage >&2
        exit 1
      }
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --format)
      [[ $# -lt 2 ]] && {
        echo "missing value for --format" >&2
        usage >&2
        exit 1
      }
      bench_v2_require_non_empty_token_filter "$1" "$2" || exit 1
      FORMAT_FILTER="$2"
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
    --output-dir)
      [[ $# -lt 2 ]] && {
        echo "missing value for --output-dir" >&2
        usage >&2
        exit 1
      }
      set_compare_root "$2"
      shift 2
      ;;
    --output)
      [[ $# -lt 2 ]] && {
        echo "missing value for --output" >&2
        usage >&2
        exit 1
      }
      echo "compare layer writes results under an output directory; use --output-dir DIR" >&2
      exit 1
      ;;
    --profile)
      [[ $# -lt 2 ]] && {
        echo "missing value for --profile" >&2
        usage >&2
        exit 1
      }
      echo "compare layer does not support --profile; select rows with external_bench manifest fields instead" >&2
      exit 1
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

if ! is_non_negative_int "$WARMUP"; then
  echo "BENCH_WARMUP/--warmup must be a non-negative integer" >&2
  exit 1
fi

if [[ "$ITERATIONS" -eq 0 ]]; then
  echo "iterations must be greater than zero" >&2
  exit 1
fi

resolve_manifest_path
parse_manifest_header

resolve_python_runner
probe_python_runner
resolve_python_version

resolve_mb_runner

rm -rf "$COMPARE_ROOT"
mkdir -p "$COMPARE_ROOT" "$PYTHON_TMPDIR" "$PYTHON_CACHE_HOME" "$PYTHON_HOME"
: > "$RESULTS_PATH"
: > "$RUNS_TSV_PATH"

GIT_REV="$(git_rev)"
MB_VERSION="markitdown-mb@${GIT_REV:-unknown}"
run_count=0
fail_count=0

echo "==> iterations: $ITERATIONS"
echo "==> warmup: $WARMUP"
echo "==> manifest: $MANIFEST_PATH"
echo "==> manifest dir: $MANIFEST_DIR"
if [[ -n "$FORMAT_FILTER" ]]; then
  echo "==> format filter: $FORMAT_FILTER"
fi
echo "==> mb runner: ${MB_COMPARE_CMD[*]}"
echo "==> mb runner kind: $MB_RUNNER_KIND"
if [[ -n "${CLI_RUNNER_NOTE:-}" && -z "$MARKITDOWN_MB_CMD" ]]; then
  echo "==> mb runner note: $CLI_RUNNER_NOTE"
fi
echo "==> python runner: ${PY_COMPARE_CMD[*]}"
echo "==> python version: $PYTHON_VERSION"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim_field "$raw_line")"
  [[ -z "$line" ]] && continue
  [[ "${line#\#}" != "$line" ]] && continue

  split_tsv_fields "$raw_line" row_fields
  bench_id="$(manifest_field bench_id row_fields)"
  format="$(lower_field "$(manifest_field format row_fields)")"
  rel_path="$(manifest_field rel_path row_fields)"
  bench_layers="$(manifest_field bench_layers row_fields)"
  enabled_tier="$(lower_field "$(manifest_field enabled_tier row_fields)")"
  source_group="$(manifest_field source_group row_fields)"
  size_class="$(lower_field "$(manifest_field size_class row_fields)")"
  bench_profile="$(manifest_field bench_profile row_fields)"
  workload_tags="$(manifest_field workload_tags row_fields)"

  if [[ "$(lower_field "$bench_id")" == "bench_id" ]] &&
    [[ "$(lower_field "$format")" == "format" ]] &&
    [[ "$(lower_field "$rel_path")" == "rel_path" ]]; then
    continue
  fi

  if [[ -z "$bench_id" ]]; then
    echo "external_bench compare row has empty bench_id: $raw_line" >&2
    exit 1
  fi

  if [[ -z "$format" ]]; then
    echo "external_bench compare row has empty format: $bench_id" >&2
    exit 1
  fi

  if [[ -z "$rel_path" ]]; then
    echo "external_bench compare row has empty rel_path: $bench_id" >&2
    exit 1
  fi

  case "$(bench_v2_enabled_tier_action "$enabled_tier")" in
    run)
      ;;
    skip)
      continue
      ;;
    error)
      echo "external_bench compare row has unsupported enabled_tier '$enabled_tier': $bench_id" >&2
      exit 1
      ;;
  esac

  if ! list_contains_token "$bench_layers" "compare"; then
    continue
  fi

  if ! format_filter_matches "$format"; then
    continue
  fi

  sample="$bench_id"
  input_path="$rel_path"
  bench_v2_reject_forbidden_path "$ROOT" "$rel_path" || exit 1
  input_abs="$(resolve_manifest_rel_path "$rel_path")"
  bench_v2_reject_forbidden_path "$ROOT" "$input_abs" || exit 1
  if [[ ! -f "$input_abs" ]]; then
    echo "external_bench input missing: $input_abs" >&2
    exit 1
  fi
  file_size="$(file_size_bytes "$input_abs")"

  if [[ "$WARMUP" -gt 0 ]]; then
    for ((warmup_iteration = 1; warmup_iteration <= WARMUP; warmup_iteration++)); do
      mb_sample_dir="$COMPARE_ROOT/mb/$format/$sample/warmup-$warmup_iteration"
      py_sample_dir="$COMPARE_ROOT/python/$format/$sample/warmup-$warmup_iteration"
      mb_output_md="$mb_sample_dir/$sample.md"
      py_output_md="$py_sample_dir/$sample.md"
      mb_stderr="$mb_sample_dir/stderr.txt"
      py_stderr="$py_sample_dir/stderr.txt"

      rm -rf "$mb_sample_dir" "$py_sample_dir"
      mkdir -p "$mb_sample_dir" "$py_sample_dir"

      echo "==> warmup mb/$format/$sample #$warmup_iteration"
      run_mb "$input_abs" "$mb_output_md" "$mb_stderr" || true
      echo "==> warmup python/$format/$sample #$warmup_iteration"
      run_python "$input_abs" "$py_output_md" "$py_stderr" || true
    done
  fi

  for iteration in $(seq 1 "$ITERATIONS"); do
    for runner_key in mb python; do
      if [[ "$runner_key" == "mb" ]]; then
        runner_name="markitdown-mb"
        runner_version="$MB_VERSION"
        sample_dir="$COMPARE_ROOT/mb/$format/$sample/iter-$iteration"
      else
        runner_name="markitdown-python"
        runner_version="$PYTHON_VERSION"
        sample_dir="$COMPARE_ROOT/python/$format/$sample/iter-$iteration"
      fi

      output_md="$sample_dir/$sample.md"
      stderr_path="$sample_dir/stderr.txt"
      rm -rf "$sample_dir"
      mkdir -p "$sample_dir"

      echo "==> benchmark $runner_key/$format/$sample iter-$iteration"
      set_now_ms
      started_ms="$NOW_MS_VALUE"
      start_precision="$TIMER_PRECISION"
      if [[ "$runner_key" == "mb" ]]; then
        if run_mb "$input_abs" "$output_md" "$stderr_path"; then
          exit_status=0
        else
          exit_status=$?
        fi
      else
        if run_python "$input_abs" "$output_md" "$stderr_path"; then
          exit_status=0
        else
          exit_status=$?
        fi
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
      stderr_bytes="$(file_size_bytes "$stderr_path")"
      timestamp="$(timestamp_utc)"

      write_result \
        "$runner_name" \
        "$runner_version" \
        "$format" \
        "$sample" \
        "$input_path" \
        "$file_size" \
        "$iteration" \
        "$elapsed_ms" \
        "$output_bytes" \
        "$stderr_bytes" \
        "$exit_status" \
        "$output_md" \
        "$stderr_path" \
        "$timestamp" \
        "$GIT_REV" \
        "$TMP_ROOT" \
        "$timer_precision" \
        "$source_group" \
        "$size_class" \
        "$bench_profile" \
        "$workload_tags" \
        "$bench_layers" \
        "$enabled_tier"

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$runner_name" \
        "$format" \
        "$sample" \
        "$exit_status" \
        "$elapsed_ms" \
        "$output_bytes" \
        "$stderr_bytes" \
        >> "$RUNS_TSV_PATH"

      run_count=$((run_count + 1))
      if [[ "$exit_status" -ne 0 ]]; then
        fail_count=$((fail_count + 1))
      fi
    done
  done
done < "$MANIFEST_PATH"

generate_summary

echo "==> result dir: $COMPARE_ROOT"
echo "==> raw results: $RESULTS_PATH"
echo "==> summary: $SUMMARY_PATH"
echo "==> mb_runner_kind: $MB_RUNNER_KIND"
echo "==> mb_runner_class: $(mb_runner_class "$MB_RUNNER_KIND")"
echo "==> python_runner_class: $(python_runner_class)"
echo "==> execution_path: compare-overlap"
echo "==> compare_meaningful: sample-scoped"
echo "==> memory_rss_available: no"
echo "==> runs: $run_count"
echo "==> failures: $fail_count"

if [[ "$run_count" -eq 0 ]]; then
  echo "no enabled compare benchmark rows selected from external_bench; check enabled_tier, bench_layers, or format filters" >&2
  exit 1
fi

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
