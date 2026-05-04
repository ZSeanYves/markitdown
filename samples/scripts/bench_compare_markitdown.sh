#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
COMPARE_ROOT="$TMP_ROOT/bench/compare"
CORPUS_PATH="$ROOT/samples/benchmark/compare_corpus.tsv"
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
MB_PREBUILT_CLI="$ROOT/_build/native/debug/build/cli/cli.exe"
PYTHON_VERSION="unknown"

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
usage: ./samples/scripts/bench_compare_markitdown.sh [--iterations N] [--warmup N] [--corpus PATH]

Environment overrides:
  BENCH_ITERATIONS            number of measured iterations per sample (default: 1)
  BENCH_WARMUP                number of unrecorded warmup runs per sample (default: 0)
  MARKITDOWN_TMP_DIR          override temp root (default: \$ROOT/.tmp)
  MARKITDOWN_MB_CMD           markitdown-mb command prefix, e.g. "_build/native/debug/build/cli/cli.exe normal"
  MARKITDOWN_COMPARE_CMD      python runner command prefix, e.g. "/path/to/markitdown"
  MARKITDOWN_COMPARE_PY_BIN   python executable that can run "python -m markitdown"

Notes:
  * This is an overlap-only benchmark between this repository runner and Microsoft MarkItDown.
  * It does not compare metadata semantics, assets semantics, or Markdown similarity.
  * It does not enable OCR plugins, Azure Document Intelligence, or other optional plugin paths.
  * By default the comparison harness builds once, then prefers the prebuilt native cli binary.
  * If no prebuilt cli binary is available, it falls back to "moon run", which includes wrapper overhead.
  * It does not create or manage a Python virtual environment inside this repository.
EOF
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
  markitdown available in PATH
  MARKITDOWN_COMPARE_CMD=/path/to/markitdown ./samples/scripts/bench_compare_markitdown.sh
  MARKITDOWN_COMPARE_PY_BIN=/path/to/python ./samples/scripts/bench_compare_markitdown.sh

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

  if [[ -x "$MB_PREBUILT_CLI" ]]; then
    MB_COMPARE_CMD=("$MB_PREBUILT_CLI" "normal")
    MB_RUNNER_KIND="prebuilt-native"
    return
  fi

  MB_COMPARE_CMD=("moon" "run" "$ROOT/cli" "--" "normal")
  MB_RUNNER_KIND="moon-run"
}

is_compare_header_row() {
  local format="${1-}"
  local sample="${2-}"
  local input_path="${3-}"
  [[ "$(lower_field "$format")" == "format" ]] &&
    [[ "$(lower_field "$sample")" == "sample" ]] &&
    [[ "$(lower_field "$input_path")" == "input_path" ]]
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

  printf '{' >> "$RESULTS_PATH"
  printf '"runner":"%s",' "$(json_escape "$runner")" >> "$RESULTS_PATH"
  printf '"version":"%s",' "$(json_escape "$version")" >> "$RESULTS_PATH"
  printf '"format":"%s",' "$(json_escape "$format")" >> "$RESULTS_PATH"
  printf '"sample":"%s",' "$(json_escape "$sample")" >> "$RESULTS_PATH"
  printf '"input_path":"%s",' "$(json_escape "$input_path")" >> "$RESULTS_PATH"
  printf '"file_size":%s,' "$file_size" >> "$RESULTS_PATH"
  printf '"iteration":%s,' "$iteration" >> "$RESULTS_PATH"
  printf '"warmup":false,' >> "$RESULTS_PATH"
  printf '"elapsed_ms":%s,' "$elapsed_ms" >> "$RESULTS_PATH"
  printf '"output_bytes":%s,' "$output_bytes" >> "$RESULTS_PATH"
  printf '"stderr_bytes":%s,' "$stderr_bytes" >> "$RESULTS_PATH"
  printf '"exit_status":%s,' "$exit_status" >> "$RESULTS_PATH"
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
    --corpus)
      [[ $# -lt 2 ]] && {
        echo "missing value for --corpus" >&2
        usage >&2
        exit 1
      }
      CORPUS_PATH="$2"
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

if ! is_non_negative_int "$WARMUP"; then
  echo "BENCH_WARMUP/--warmup must be a non-negative integer" >&2
  exit 1
fi

if [[ "$ITERATIONS" -eq 0 ]]; then
  echo "iterations must be greater than zero" >&2
  exit 1
fi

if [[ ! -f "$CORPUS_PATH" ]]; then
  echo "comparison corpus missing: $CORPUS_PATH" >&2
  exit 1
fi

resolve_python_runner
probe_python_runner
resolve_python_version

echo "==> warming Moon build"
if ! (cd "$ROOT" && moon build >/dev/null); then
  echo "moon build failed" >&2
  exit 1
fi

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
echo "==> corpus: $CORPUS_PATH"
echo "==> mb runner: ${MB_COMPARE_CMD[*]}"
echo "==> mb runner kind: $MB_RUNNER_KIND"
echo "==> python runner: ${PY_COMPARE_CMD[*]}"
echo "==> python version: $PYTHON_VERSION"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim_field "$raw_line")"
  [[ -z "$line" ]] && continue
  [[ "${line#\#}" != "$line" ]] && continue

  IFS=$'\t' read -r format sample input_path _extra <<< "$raw_line"
  format="$(trim_field "$format")"
  sample="$(trim_field "$sample")"
  input_path="$(trim_field "$input_path")"

  if is_compare_header_row "$format" "$sample" "$input_path"; then
    continue
  fi

  if [[ -z "$format" || -z "$sample" || -z "$input_path" ]]; then
    echo "skip malformed comparison row: $raw_line" >&2
    continue
  fi

  input_abs="$(resolve_input_path "$input_path")"
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
        "$timer_precision"

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
done < "$CORPUS_PATH"

generate_summary

echo "==> comparison results: $RESULTS_PATH"
echo "==> comparison summary: $SUMMARY_PATH"
echo "==> runs: $run_count"
echo "==> failures: $fail_count"

if [[ "$run_count" -eq 0 ]]; then
  echo "no comparison rows executed" >&2
  exit 1
fi

if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
