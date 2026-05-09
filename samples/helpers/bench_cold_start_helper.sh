#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
RESULT_ROOT="$TMP_ROOT/bench/cold_start"
OUTPUT_DIR="$RESULT_ROOT"
ITERATIONS=50
WARMUP=5

usage() {
  cat <<'EOF'
Usage: ./samples/helpers/bench_cold_start_helper.sh [--iterations N] [--warmup N] [--output-dir PATH]

Notes:
  * Recommended public entrypoint:
      ./samples/bench.sh --suite cold-start --kind cli ...
  * This harness measures both external cold-start wall-clock time and hidden
    main-internal startup timing.
  * same-process product-path totals are intentionally tracked elsewhere.
  * --version is currently not a supported CLI contract, so version cases are
    recorded as skipped observations.
EOF
}

now_us() {
  local raw
  raw="$(date +%s%N 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ ${#raw} -gt 10 ]]; then
    printf '%s\n' "$((raw / 1000))"
    return
  fi

  raw="$(LC_ALL=C LANG=C perl -MTime::HiRes=time -e 'print int(time()*1000000), qq(\n)' 2>/dev/null || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$raw"
    return
  fi

  local secs
  secs="$(date +%s 2>/dev/null || true)"
  if [[ "$secs" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$((secs * 1000000))"
    return
  fi

  printf '0\n'
}

emit_skip_row() {
  local case_name="$1"
  local binary_kind="$2"
  local command="$3"
  local notes="$4"
  printf '%s\t%s\t%s\t0\t0.000\t0.000\t0.000\t0.000\t0.000\t0.000\t0.000\t%s\n' \
    "$case_name" "$binary_kind" "$command" "$notes" >> "$SUMMARY_PATH"
}

internal_profile_total_us() {
  local case_name="$1"
  local binary_kind="$2"
  local bin_path="$3"
  local iteration="$4"
  local output_path="${5:-}"
  local profile_path="$WORK_ROOT/${binary_kind}.${case_name}.startup_profile.tsv"
  local -a cmd=( "$bin_path" _bench-startup-profile )

  case "$case_name" in
    noop)
      cmd+=(noop)
      ;;
    help)
      cmd+=(help)
      ;;
    normal_txt_small)
      cmd+=(normal_txt_small --input "$ROOT/samples/benchmark/txt/txt_small.txt" --output "$output_path")
      ;;
    *)
      echo "unsupported internal cold-start case: $case_name" >&2
      exit 1
      ;;
  esac

  if [[ -n "$output_path" ]]; then
    rm -f "$output_path"
  fi
  "${cmd[@]}" > "$profile_path"

  python3 - "$profile_path" "$STAGE_RUNS_PATH" "$case_name" "$binary_kind" "$iteration" <<'PY'
import csv
import sys

profile_path, stage_runs_path, case_name, binary_kind, iteration = sys.argv[1:]
before_exit = None

with open(profile_path, newline="") as src, open(stage_runs_path, "a", newline="") as dst:
    reader = csv.DictReader(src, delimiter="\t")
    writer = csv.writer(dst, delimiter="\t", lineterminator="\n")
    for row in reader:
        notes = row.get("notes", "")
        writer.writerow([
            case_name,
            binary_kind,
            iteration,
            row["stage"],
            row["elapsed_us"],
            notes,
        ])
        if row["stage"] == "before_exit":
            before_exit = int(row["elapsed_us"])

if before_exit is None:
    raise SystemExit("missing before_exit row in startup profile")

print(before_exit)
PY
}

measure_case() {
  local case_name="$1"
  local binary_kind="$2"
  local bin_path="$3"
  local command_desc="$4"
  local notes="$5"
  shift 5
  local -a cmd=( "$bin_path" "$@" )
  local total_iterations=$((ITERATIONS + WARMUP))
  local iter
  local measured_iter
  local start_us
  local end_us
  local external_elapsed_us
  local main_internal_us
  local output_path=""

  if [[ "$case_name" == "normal_txt_small" ]]; then
    output_path="$WORK_ROOT/${binary_kind}.${case_name}.md"
    cmd=( "$bin_path" normal "$ROOT/samples/benchmark/txt/txt_small.txt" "$output_path" )
  fi

  for ((iter = 1; iter <= total_iterations; iter++)); do
    if [[ -n "$output_path" ]]; then
      rm -f "$output_path"
    fi
    start_us="$(now_us)"
    "${cmd[@]}" >/dev/null 2>&1
    end_us="$(now_us)"
    external_elapsed_us=$((end_us - start_us))

    if (( iter > WARMUP )); then
      measured_iter=$((iter - WARMUP))
      main_internal_us="$(internal_profile_total_us "$case_name" "$binary_kind" "$bin_path" "$measured_iter" "$output_path")"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$case_name" "$binary_kind" "$command_desc" "$measured_iter" "$external_elapsed_us" "$main_internal_us" "$notes" >> "$RUNS_PATH"
    fi
  done
}

summarize_runs() {
  python3 - "$RUNS_PATH" "$SUMMARY_PATH" "$STAGE_RUNS_PATH" "$STAGE_SUMMARY_PATH" "$ITERATIONS" <<'PY'
import csv
import math
import sys
from collections import defaultdict

runs_path, summary_path, stage_runs_path, stage_summary_path, iterations = (
    sys.argv[1],
    sys.argv[2],
    sys.argv[3],
    sys.argv[4],
    int(sys.argv[5]),
)


def p50(values):
    return values[(len(values) - 1) // 2]


def p95(values):
    return values[max(0, min(len(values) - 1, math.ceil(len(values) * 0.95) - 1))]


rows = defaultdict(list)
notes_by_key = {}

with open(runs_path, newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        key = (row["case"], row["binary_kind"], row["command"])
        rows[key].append(
            (
                float(row["external_elapsed_us"]) / 1000.0,
                float(row["main_internal_elapsed_us"]) / 1000.0,
            )
        )
        notes_by_key[key] = row["notes"]

with open(summary_path, "a", newline="") as f:
    writer = csv.writer(f, delimiter="\t", lineterminator="\n")
    for key in sorted(rows):
        external_values = sorted(v[0] for v in rows[key])
        internal_values = sorted(v[1] for v in rows[key])
        external_avg = sum(external_values) / len(external_values)
        internal_avg = sum(internal_values) / len(internal_values)
        writer.writerow(
            [
                key[0],
                key[1],
                key[2],
                iterations,
                f"{external_avg:.3f}",
                f"{p50(external_values):.3f}",
                f"{p95(external_values):.3f}",
                f"{internal_avg:.3f}",
                f"{p50(internal_values):.3f}",
                f"{p95(internal_values):.3f}",
                f"{external_avg - internal_avg:.3f}",
                notes_by_key.get(key, "timed_externally=true"),
            ]
        )

stage_rows = defaultdict(list)
stage_notes = {}

with open(stage_runs_path, newline="") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        key = (row["case"], row["binary_kind"], row["stage"])
        stage_rows[key].append(float(row["elapsed_us"]))
        stage_notes[key] = row.get("notes", "")

with open(stage_summary_path, "w", newline="") as f:
    writer = csv.writer(f, delimiter="\t", lineterminator="\n")
    writer.writerow(
        [
            "case",
            "binary_kind",
            "stage",
            "iterations",
            "avg_us",
            "p50_us",
            "p95_us",
            "max_us",
            "notes",
        ]
    )
    for key in sorted(stage_rows):
        values = sorted(stage_rows[key])
        writer.writerow(
            [
                key[0],
                key[1],
                key[2],
                len(values),
                f"{sum(values) / len(values):.0f}",
                f"{p50(values):.0f}",
                f"{p95(values):.0f}",
                f"{max(values):.0f}",
                stage_notes.get(key, ""),
            ]
        )
PY
}

print_summary_rows() {
  echo "slowest cold-start rows:"
  tail -n +2 "$SUMMARY_PATH" | sort -t $'\t' -k5,5nr \
    | awk -F '\t' '{ print $1 " [" $2 "] external_avg=" $5 "ms main_internal_avg=" $8 "ms process_runtime_est=" $11 "ms notes=" $12 }' \
    | head -n 10 | sed 's/^/- /'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
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
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
WORK_ROOT="$OUTPUT_DIR/work"
mkdir -p "$WORK_ROOT"
SUMMARY_PATH="$OUTPUT_DIR/summary.tsv"
RUNS_PATH="$OUTPUT_DIR/summary.runs.tsv"
STAGE_RUNS_PATH="$OUTPUT_DIR/startup_profile.runs.tsv"
STAGE_SUMMARY_PATH="$OUTPUT_DIR/startup_profile.summary.tsv"

echo "==> cold-start CLI benchmark"
echo "output_dir: $OUTPUT_DIR"
DEBUG_BIN="$ROOT/_build/native/debug/build/cli/cli.exe"
RELEASE_BIN="$ROOT/_build/native/release/build/cli/cli.exe"

echo "==> refreshing debug native CLI"
(cd "$ROOT" && moon build --target native >/dev/null)

[[ -x "$DEBUG_BIN" ]] || { echo "missing debug native CLI binary: $DEBUG_BIN" >&2; exit 1; }

printf 'case\tbinary_kind\tcommand\titeration\texternal_elapsed_us\tmain_internal_elapsed_us\tnotes\n' > "$RUNS_PATH"
printf 'case\tbinary_kind\titeration\tstage\telapsed_us\tnotes\n' > "$STAGE_RUNS_PATH"
printf 'case\tbinary_kind\tcommand\titerations\texternal_avg_ms\texternal_p50_ms\texternal_p95_ms\tmain_internal_avg_ms\tmain_internal_p50_ms\tmain_internal_p95_ms\testimated_process_runtime_ms\tnotes\n' > "$SUMMARY_PATH"

echo "runner: debug-native ($DEBUG_BIN)"
measure_case "noop" "debug-native" "$DEBUG_BIN" "_bench-noop" "runner_path=$DEBUG_BIN command_class=noop timed_externally=true main_internal_hidden_profile=true equivalent_to=product_path_startup_probe" "_bench-noop"
measure_case "help" "debug-native" "$DEBUG_BIN" "--help" "runner_path=$DEBUG_BIN command_class=help timed_externally=true main_internal_hidden_profile=true" "--help"
measure_case "normal_txt_small" "debug-native" "$DEBUG_BIN" "normal txt_small -> tmp.md" "runner_path=$DEBUG_BIN command_class=minimal_real_conversion timed_externally=true main_internal_hidden_profile=true"

release_build_supported=true
echo "==> refreshing release native CLI"
if ! (cd "$ROOT" && moon build --target native --release >/dev/null 2>&1); then
  release_build_supported=false
fi

if [[ "$release_build_supported" == true && -x "$RELEASE_BIN" ]]; then
  echo "runner: release-native ($RELEASE_BIN)"
  measure_case "noop" "release-native" "$RELEASE_BIN" "_bench-noop" "runner_path=$RELEASE_BIN command_class=noop timed_externally=true main_internal_hidden_profile=true equivalent_to=product_path_startup_probe" "_bench-noop"
  measure_case "help" "release-native" "$RELEASE_BIN" "--help" "runner_path=$RELEASE_BIN command_class=help timed_externally=true main_internal_hidden_profile=true" "--help"
  measure_case "normal_txt_small" "release-native" "$RELEASE_BIN" "normal txt_small -> tmp.md" "runner_path=$RELEASE_BIN command_class=minimal_real_conversion timed_externally=true main_internal_hidden_profile=true"
  emit_skip_row "version" "debug-native" "--version" "skip_reason=unsupported_cli_contract"
  emit_skip_row "version" "release-native" "--version" "skip_reason=unsupported_cli_contract"
else
  echo "runner: release-native unavailable"
  emit_skip_row "version" "debug-native" "--version" "skip_reason=unsupported_cli_contract"
  emit_skip_row "version" "release-native" "--version" "skip_reason=release_build_unsupported_or_missing_binary"
fi

summarize_runs

echo "cold-start benchmark completed"
echo "summary: $SUMMARY_PATH"
echo "raw runs: $RUNS_PATH"
echo "startup-profile runs: $STAGE_RUNS_PATH"
echo "startup-profile summary: $STAGE_SUMMARY_PATH"
print_summary_rows

echo "BENCHMARK SUITE COMPLETED"
echo "- suite: cold-start"
echo "- result_root: $OUTPUT_DIR"
echo "- summary_tsv: $SUMMARY_PATH"
echo "- raw_runs_tsv: $RUNS_PATH"
echo "- artifact: $STAGE_RUNS_PATH"
echo "- artifact: $STAGE_SUMMARY_PATH"
