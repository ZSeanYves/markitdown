#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
RESULT_ROOT="$TMP_ROOT/bench/product_path"
DEFAULT_MANIFEST="$ROOT/samples/product_path_bench/manifest.tsv"
DEFAULT_OUTPUT_DIR="$RESULT_ROOT"
PLAN_CORPUS="$ROOT/samples/benchmark/corpus.tsv"
FORMATS=""
ITERATIONS=10
WARMUP=2
MODE="run"
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
MANIFEST_PATH="$DEFAULT_MANIFEST"
CORPUS_PATH="$PLAN_CORPUS"

usage() {
  cat <<'EOF'
Usage: ./samples/bench_product_path.sh --help
   or: ./samples/bench_product_path.sh --smoke [--corpus PATH] [--output-dir PATH] [--formats txt,json,...]
   or: ./samples/bench_product_path.sh [--manifest PATH] [--iterations N] [--warmup N] [--format txt,json,...] [--output-dir PATH]

Notes:
  * This harness measures the markitdown product path, not the direct doc_parse API.
  * It uses a hidden benchmark-only CLI entrypoint and does not change normal CLI behavior.
  * startup_probe is measured separately with a no-op CLI launch.
  * file_read is a standalone probe row; current parse rows still include the
    converter-local file read inside the real conversion path.
  * parse vs convert is now split for txt/json/yaml/csv/xlsx and native text-PDF.
  * html/docx/pptx now expose richer converter-owned substages, but html is the
    cleanest split; docx/pptx still keep partial combined seams in their current
    normal-path converters.
EOF
}

resolve_path() {
  local path="${1-}"
  if [[ "$path" == /* ]]; then
    printf '%s' "$path"
  else
    printf '%s/%s' "$ROOT" "$path"
  fi
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

format_filter_match() {
  local format="${1-}"
  if [[ -z "$FORMATS" ]]; then
    return 0
  fi
  local wrapped=",$FORMATS,"
  [[ "$wrapped" == *",$format,"* ]]
}

is_true_flag() {
  local raw
  raw="$(printf '%s' "${1-}" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    true|1|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

file_size_bytes() {
  local path="${1-}"
  if [[ -f "$path" ]]; then
    wc -c < "$path" | tr -d '[:space:]'
  else
    printf '0'
  fi
}

generate_plan_artifacts() {
  mkdir -p "$OUTPUT_DIR"

  local stage_plan="$OUTPUT_DIR/stage-plan.tsv"
  local sample_plan="$OUTPUT_DIR/sample-plan.tsv"

  cat > "$stage_plan" <<'EOF'
stage	owner_layer	planned_instrumentation	notes
startup_probe	cli	process launch and empty command baseline	separate fixed startup from format-local work
file_read	cli-or-probe	standalone file-read probe	current harness keeps this as a probe row, not subtracted from parse
dispatch	cli	format detection and option routing	exact stage inside same-process benchmark run
parse	doc_parse-or-convert	current converter parse entry	refined harness splits txt/json/yaml/csv/xlsx; html is cleanly split; docx/pptx are partially split with staged converter substages
convert	convert	current lowering seam	refined harness splits txt/json/yaml/csv/xlsx/html; docx/pptx remain partially combined
emit	emitter	markdown emission plus markdown write	measured inside same-process benchmark run
metadata	metadata	sidecar build plus write	measured only when enabled for a manifest row
assets	assets	asset scan/export/copy	refined harness reports staged discovery/export boundaries for html/docx/pptx current converter-local asset paths
total	product	full same-process normal path	startup_probe is measured separately
EOF

  awk -F '\t' -v formats=",$FORMATS," '
BEGIN {
  print "run_kind\tformat\tsample\tinput_path\tmetadata_enabled\tproposed_stages\tnotes"
}
/^#/ { next }
NR == 1 { next }
{
  if (formats != "," && index(formats, "," $2 ",") == 0) {
    next
  }
  if ($1 == "smoke") {
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\tstartup_probe,file_read,dispatch,parse,convert,emit,total\tbaseline normal-path candidate"
  } else if ($1 == "metadata") {
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\tstartup_probe,file_read,dispatch,parse,convert,emit,metadata,total\tmetadata sidecar attribution candidate"
  } else if ($1 == "image") {
    print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\tstartup_probe,file_read,dispatch,parse,convert,emit,assets,total\tasset export attribution candidate"
  }
}
' "$CORPUS_PATH" > "$sample_plan"

  echo "PRODUCT PATH ATTRIBUTION PLAN READY"
  echo "- corpus: $CORPUS_PATH"
  echo "- output_dir: $OUTPUT_DIR"
  echo "- stage_plan: $stage_plan"
  echo "- sample_plan: $sample_plan"
}

generate_summary() {
  local runs_path="${1-}"
  local summary_path="${2-}"

  awk -F '\t' '
function sort_numeric(values, n,    i, j, tmp) {
  for (i = 2; i <= n; i++) {
    tmp = values[i] + 0
    j = i - 1
    while (j >= 1 && values[j] + 0 > tmp) {
      values[j + 1] = values[j]
      j--
    }
    values[j + 1] = tmp
  }
}

function us_to_ms(us) {
  return sprintf("%.3f", us / 1000.0)
}

function percentile_index(n, pct) {
  if (n <= 0) {
    return 1
  }
  idx = int((n * pct + 99) / 100)
  if (idx < 1) {
    idx = 1
  }
  if (idx > n) {
    idx = n
  }
  return idx
}

BEGIN {
  OFS = "\t"
}

NR == 1 {
  next
}

{
  key = $1 "\t" $2 "\t" $3
  format[key] = $1
  sample[key] = $2
  stage[key] = $3
  count[key] += 1
  sum[key] += $5 + 0
  if (!(key in min) || ($5 + 0) < min[key]) {
    min[key] = $5 + 0
  }
  if (!(key in max) || ($5 + 0) > max[key]) {
    max[key] = $5 + 0
  }
  values[key] = values[key] " " ($5 + 0)
  bytes[key] = $6
  if (!(key in notes) && $7 != "") {
    notes[key] = $7
  }
}

END {
  print "format", "sample", "stage", "iterations", "total_ms", "avg_ms", "min_ms", "p50_ms", "p95_ms", "max_ms", "bytes", "notes"
  for (key in count) {
    n = split(substr(values[key], 2), arr, " ")
    sort_numeric(arr, n)
    total = sum[key]
    avg = total / count[key]
    p50 = arr[int((n + 1) / 2)] + 0
    p95 = arr[percentile_index(n, 95)] + 0
    print format[key], sample[key], stage[key], count[key], us_to_ms(total), us_to_ms(avg), us_to_ms(min[key]), us_to_ms(p50), us_to_ms(p95), us_to_ms(max[key]), bytes[key], notes[key]
  }
}
' "$runs_path" > "$summary_path.unsorted"

  {
    head -n 1 "$summary_path.unsorted"
    tail -n +2 "$summary_path.unsorted" | sort -t $'\t' -k6,6nr
  } > "$summary_path"
  rm -f "$summary_path.unsorted"
}

print_slowest_rows() {
  local summary_path="${1-}"
  echo "slowest total rows:"
  awk -F '\t' 'NR == 1 { next } $3 == "total" { print $1 "/" $2 " avg=" $6 "ms notes=" $12 }' "$summary_path" | head -n 10 | sed 's/^/- /'
  echo "slowest stage rows:"
  awk -F '\t' 'NR == 1 { next } $3 != "total" { print $1 "/" $2 " [" $3 "] avg=" $6 "ms notes=" $12 }' "$summary_path" | head -n 10 | sed 's/^/- /'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --smoke)
      MODE="smoke"
      shift
      ;;
    --manifest)
      [[ $# -ge 2 ]] || { echo "missing value for --manifest" >&2; exit 1; }
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --corpus)
      [[ $# -ge 2 ]] || { echo "missing value for --corpus" >&2; exit 1; }
      CORPUS_PATH="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || { echo "missing value for --output-dir" >&2; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --format|--formats)
      [[ $# -ge 2 ]] || { echo "missing value for --format/--formats" >&2; exit 1; }
      FORMATS="$2"
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
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$MODE" == "smoke" ]]; then
  generate_plan_artifacts
  exit 0
fi

mkdir -p "$OUTPUT_DIR"
SUMMARY_PATH="$OUTPUT_DIR/summary.tsv"
RUNS_PATH="$OUTPUT_DIR/summary.runs.tsv"
WORK_ROOT="$OUTPUT_DIR/work"
mkdir -p "$WORK_ROOT"

echo "==> product-path attribution benchmark"
echo "manifest: $MANIFEST_PATH"
echo "output_dir: $OUTPUT_DIR"
echo "==> warming Moon build"
(cd "$ROOT" && moon build --target native)

CLI_BIN=""
while IFS= read -r candidate; do
  [[ -n "$candidate" ]] || continue
  CLI_BIN="$candidate"
  break
done < <(find "$ROOT/_build/native" -path "*/cli/*.exe" -type f 2>/dev/null | sort)

if [[ -z "$CLI_BIN" || ! -x "$CLI_BIN" ]]; then
  echo "failed to locate native CLI binary under _build/native" >&2
  exit 1
fi

echo "runner: prebuilt-native ($CLI_BIN)"

printf 'format\tsample\tstage\titeration\telapsed_us\tbytes\tnotes\n' > "$RUNS_PATH"

total_iterations=$((ITERATIONS + WARMUP))
for ((iter = 1; iter <= total_iterations; iter++)); do
  start_us="$(now_us)"
  "$CLI_BIN" _bench-noop >/dev/null 2>&1
  end_us="$(now_us)"
  elapsed_us=$((end_us - start_us))
  if (( iter > WARMUP )); then
    measured_iter=$((iter - WARMUP))
    printf 'cli\tstartup_probe\tstartup_probe\t%s\t%s\t0\trunner=native-binary noop=true\n' \
      "$measured_iter" "$elapsed_us" >> "$RUNS_PATH"
  fi
done

while IFS=$'\t' read -r format path label size_class with_metadata with_assets notes; do
  [[ -n "${format:-}" ]] || continue
  [[ "$format" == "format" ]] && continue
  [[ "$format" == \#* ]] && continue
  format="$(printf '%s' "$format" | tr '[:upper:]' '[:lower:]')"
  if ! format_filter_match "$format"; then
    continue
  fi

  input_path="$(resolve_path "$path")"
  bytes="$(file_size_bytes "$input_path")"
  metadata_flag=false
  assets_flag=false
  if is_true_flag "$with_metadata"; then
    metadata_flag=true
  fi
  if is_true_flag "$with_assets"; then
    assets_flag=true
  fi

  echo "==> benchmark $format/$label"
  for ((iter = 1; iter <= total_iterations; iter++)); do
    run_root="$WORK_ROOT/${label}.iter-${iter}"
    mkdir -p "$run_root"
    cmd=()
    case "$format" in
      txt)
        cmd+=("MARKITDOWN_PROFILE_TXT=1")
        ;;
      json)
        cmd+=("MARKITDOWN_PROFILE_JSON=1")
        ;;
      yaml)
        cmd+=("MARKITDOWN_PROFILE_YAML=1")
        ;;
      csv|tsv)
        cmd+=("MARKITDOWN_PROFILE_CSV=1")
        ;;
      xlsx)
        cmd+=("MARKITDOWN_PROFILE_XLSX=1")
        ;;
      pdf)
        cmd+=("MARKITDOWN_PROFILE_PDF_CONVERT=1")
        cmd+=("MARKITDOWN_PROFILE_PDF_CONVERT_PATH=$run_root/.pdf.profile.log")
        ;;
      html)
        cmd+=("MARKITDOWN_PROFILE_HTML=1")
        cmd+=("MARKITDOWN_PROFILE_HTML_PATH=$run_root/.html.profile.log")
        ;;
      docx)
        cmd+=("MARKITDOWN_PROFILE_DOCX_CONVERT=1")
        cmd+=("MARKITDOWN_PROFILE_DOCX_CONVERT_PATH=$run_root/.docx.profile.log")
        ;;
      pptx)
        cmd+=("MARKITDOWN_PROFILE_PPTX_CONVERT=1")
        cmd+=("MARKITDOWN_PROFILE_PPTX_CONVERT_PATH=$run_root/.pptx.profile.log")
        ;;
    esac
    cmd+=("$CLI_BIN" "_bench-product-path" "--input" "$input_path" "--output-root" "$run_root")
    if [[ "$metadata_flag" == true ]]; then
      cmd+=("--with-metadata")
    fi
    if [[ "$assets_flag" == true ]]; then
      cmd+=("--with-assets")
    fi
    output="$(env "${cmd[@]}")"

    if (( iter <= WARMUP )); then
      continue
    fi

    measured_iter=$((iter - WARMUP))
    while IFS=$'\t' read -r stage elapsed_us stage_notes; do
      [[ -n "${stage:-}" ]] || continue
      [[ "$stage" == "stage" ]] && continue
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$format" "$label" "$stage" "$measured_iter" "$elapsed_us" "$bytes" "${stage_notes:-$notes}" >> "$RUNS_PATH"
    done <<< "$output"
  done
done < "$MANIFEST_PATH"

generate_summary "$RUNS_PATH" "$SUMMARY_PATH"

echo "product-path benchmark completed"
echo "summary: $SUMMARY_PATH"
echo "raw runs: $RUNS_PATH"
print_slowest_rows "$SUMMARY_PATH"

echo "BENCHMARK SUITE COMPLETED"
echo "- suite: product-path"
echo "- result_root: $OUTPUT_DIR"
echo "- summary_tsv: $SUMMARY_PATH"
echo "- raw_runs_tsv: $RUNS_PATH"
