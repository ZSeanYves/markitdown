#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"

TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}/bench/helpers"
TMP_DIR=""
CLI_BIN=""
PDF_CLI_BIN=""
ZIP_CLI_BIN=""
RUNS="${BENCH_ITERATIONS:-3}"
WARMUP="${BENCH_WARMUP:-1}"

usage() {
  cat <<'EOF'
usage: bash samples/helpers/bench/check_product_path_attribution_smoke.sh [--help] [--runs N] [--warmup N]

Read-only product-path attribution smoke using the public native CLI.

Requirements:
  * prebuilt native CLI
  * recommended command:
      moon build cli --target native

Environment overrides:
  MARKITDOWN_CLI      path to prebuilt native cli.exe
  MARKITDOWN_PDF_CLI  optional prebuilt native pdf.exe override
  MARKITDOWN_ZIP_CLI  optional prebuilt native zip.exe override
  BENCH_ITERATIONS    measured runs per case (default: 3)
  BENCH_WARMUP        unrecorded warmup runs per case (default: 1)
  MARKITDOWN_TMP_DIR  override temp root (default: .tmp)

Output columns:
  case mode runs median_ms min_ms max_ms input output_bytes notes

Notes:
  * this helper does not run OCR or tesseract
  * this helper does not build binaries internally
  * batch mode is measured separately as a directional amortization signal
EOF
}

cleanup() {
  sample_cleanup_tmp_dir "$TMP_DIR"
}

trap cleanup EXIT

trim_field() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

is_non_negative_int() {
  [[ "${1-}" =~ ^[0-9]+$ ]]
}

resolve_cli_path() {
  local override="${MARKITDOWN_CLI:-}"
  if [[ -n "$override" ]]; then
    if [[ ! -x "$override" ]]; then
      echo "MARKITDOWN_CLI is set but not executable: $override" >&2
      exit 2
    fi
    CLI_BIN="$override"
    return
  fi

  local candidate
  for candidate in \
    "$ROOT/_build/native/debug/build/cli/cli.exe" \
    "$ROOT/_build/native/release/build/cli/cli.exe"
  do
    if [[ -x "$candidate" ]]; then
      CLI_BIN="$candidate"
      return
    fi
  done

  echo "failed to locate a prebuilt native CLI. Run: moon build cli --target native" >&2
  exit 2
}

resolve_component_cli() {
  local package="$1"
  local env_name="$2"
  local result_var="$3"
  local override="${!env_name:-}"
  local found=""

  if [[ -n "$override" ]]; then
    if [[ ! -x "$override" ]]; then
      echo "$env_name is set but not executable: $override" >&2
      exit 2
    fi
    found="$override"
  else
    local candidate
    for candidate in \
      "$ROOT/_build/native/debug/build/$package/$package.exe" \
      "$ROOT/_build/native/release/build/$package/$package.exe"
    do
      if [[ -x "$candidate" ]]; then
        found="$candidate"
        break
      fi
    done
  fi

  printf -v "$result_var" '%s' "$found"
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

ms_from_us() {
  awk -v value_us="$1" 'BEGIN { printf "%.3f", value_us / 1000.0 }'
}

compute_stats() {
  local values_string="$1"
  awk '
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
{
  n = split($0, arr, " ")
  sort_numeric(arr, n)
  min = arr[1] + 0
  max = arr[n] + 0
  if (n % 2 == 1) {
    median = arr[(n + 1) / 2] + 0
  } else {
    median = (arr[n / 2] + arr[n / 2 + 1]) / 2.0
  }
  printf "%s\t%s\t%s\n", us_to_ms(median), us_to_ms(min), us_to_ms(max)
}
' <<< "$values_string"
}

file_size_bytes() {
  local path="${1-}"
  if [[ -f "$path" ]]; then
    wc -c < "$path" | tr -d '[:space:]'
  else
    printf '0'
  fi
}

count_files_under() {
  local path="${1-}"
  if [[ -d "$path" ]]; then
    find "$path" -type f | wc -l | tr -d '[:space:]'
  else
    printf '0'
  fi
}

run_cli_timed() {
  local start_us end_us elapsed_us output status
  start_us="$(now_us)"
  output="$(
    MARKITDOWN_PDF_CLI="$PDF_CLI_BIN" MARKITDOWN_ZIP_CLI="$ZIP_CLI_BIN" "$@" 2>&1
  )" || status=$?
  status="${status:-0}"
  if [[ "$status" -ne 0 ]]; then
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" >&2
    fi
    return 1
  fi
  end_us="$(now_us)"
  elapsed_us=$((end_us - start_us))
  printf '%s\n' "$elapsed_us"
}

report_case() {
  local case_name="$1"
  local mode="$2"
  local input_path="$3"
  local output_bytes="$4"
  local notes="$5"
  shift 5

  local -a values=("$@")
  local joined=""
  local value
  for value in "${values[@]}"; do
    if [[ -z "$joined" ]]; then
      joined="$value"
    else
      joined="$joined $value"
    fi
  done

  local stats
  stats="$(compute_stats "$joined")"
  local median_ms min_ms max_ms
  IFS=$'\t' read -r median_ms min_ms max_ms <<< "$stats"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$case_name" \
    "$mode" \
    "${#values[@]}" \
    "$median_ms" \
    "$min_ms" \
    "$max_ms" \
    "$input_path" \
    "$output_bytes" \
    "$notes"
}

run_normal_case() {
  local case_name="$1"
  local input_path="$2"
  local mode="$3"
  local with_metadata="$4"
  local expect_assets="$5"
  local notes="$6"

  local total_runs=$((RUNS + WARMUP))
  local -a values=()
  local iter elapsed_us out_dir output_md output_bytes asset_count metadata_count

  for ((iter = 1; iter <= total_runs; iter++)); do
    out_dir="$TMP_DIR/$case_name.$mode.iter-$iter/out"
    mkdir -p "$out_dir"
    output_md="$out_dir/"
    if [[ "$with_metadata" == "true" ]]; then
      elapsed_us="$(run_cli_timed "$CLI_BIN" normal --with-metadata "$input_path" "$output_md")" || {
        echo "normal conversion failed for $case_name ($mode)" >&2
        exit 1
      }
    else
      elapsed_us="$(run_cli_timed "$CLI_BIN" normal "$input_path" "$output_md")" || {
        echo "normal conversion failed for $case_name ($mode)" >&2
        exit 1
      }
    fi

    if (( iter <= WARMUP )); then
      continue
    fi

    values+=("$elapsed_us")
  done

  output_bytes="$(file_size_bytes "$TMP_DIR/$case_name.$mode.iter-$total_runs/out/$(basename "${input_path%.*}").md")"
  asset_count="$(count_files_under "$TMP_DIR/$case_name.$mode.iter-$total_runs/out/assets")"
  metadata_count="$(count_files_under "$TMP_DIR/$case_name.$mode.iter-$total_runs/out/metadata")"

  if [[ "$expect_assets" == "true" ]]; then
    notes="$notes asset_files=$asset_count"
  else
    notes="$notes asset_files=$asset_count"
  fi
  notes="$notes metadata_files=$metadata_count"
  report_case "$case_name" "$mode" "$input_path" "$output_bytes" "$notes" "${values[@]}"
}

run_batch_case() {
  local case_name="$1"
  local with_metadata="$2"
  local notes="$3"

  local batch_in="$TMP_DIR/$case_name.batch.input"
  local batch_out="$TMP_DIR/$case_name.batch.out"
  mkdir -p "$batch_in"
  cp "$ROOT/samples/main_process/txt/txt_plain.txt" "$batch_in/"
  cp "$ROOT/samples/main_process/json/metadata/json_metadata_nested.json" "$batch_in/"

  local total_runs=$((RUNS + WARMUP))
  local -a values=()
  local iter elapsed_us summary_path output_bytes metadata_count

  for ((iter = 1; iter <= total_runs; iter++)); do
    rm -rf "$batch_out"
    mkdir -p "$batch_out"
    if [[ "$with_metadata" == "true" ]]; then
      elapsed_us="$(run_cli_timed "$CLI_BIN" batch --with-metadata "$batch_in" "$batch_out")" || {
        echo "batch conversion failed for $case_name" >&2
        exit 1
      }
    else
      elapsed_us="$(run_cli_timed "$CLI_BIN" batch "$batch_in" "$batch_out")" || {
        echo "batch conversion failed for $case_name" >&2
        exit 1
      }
    fi

    if (( iter <= WARMUP )); then
      continue
    fi

    values+=("$elapsed_us")
  done

  output_bytes="$(find "$batch_out" -type f -name '*.md' -exec wc -c {} + 2>/dev/null | awk 'END { print $1 + 0 }')"
  metadata_count="$(find "$batch_out" -type f -path '*/metadata/*.json' | wc -l | tr -d '[:space:]')"
  notes="$notes markdown_files=2 metadata_files=$metadata_count"
  report_case "$case_name" "batch" "$batch_in" "$output_bytes" "$notes" "${values[@]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --runs)
      [[ $# -ge 2 ]] || { echo "missing value for --runs" >&2; exit 2; }
      RUNS="$(trim_field "$2")"
      shift 2
      ;;
    --warmup)
      [[ $# -ge 2 ]] || { echo "missing value for --warmup" >&2; exit 2; }
      WARMUP="$(trim_field "$2")"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! is_non_negative_int "$RUNS" || [[ "$RUNS" -eq 0 ]]; then
  echo "--runs must be a positive integer" >&2
  exit 2
fi

if ! is_non_negative_int "$WARMUP"; then
  echo "--warmup must be a non-negative integer" >&2
  exit 2
fi

resolve_cli_path
resolve_component_cli "pdf" "MARKITDOWN_PDF_CLI" PDF_CLI_BIN
resolve_component_cli "zip" "MARKITDOWN_ZIP_CLI" ZIP_CLI_BIN

TMP_DIR="$(sample_make_isolated_tmp_dir "$TMP_ROOT" "bench_product_path_smoke")"

printf 'case\tmode\truns\tmedian_ms\tmin_ms\tmax_ms\tinput\toutput_bytes\tnotes\n'

run_normal_case \
  "txt_plain" \
  "$ROOT/samples/main_process/txt/txt_plain.txt" \
  "markdown_only" \
  "false" \
  "false" \
  "path=normal startup_included=true metadata_enabled=false"

run_normal_case \
  "json_metadata_nested" \
  "$ROOT/samples/main_process/json/metadata/json_metadata_nested.json" \
  "markdown_plus_metadata" \
  "true" \
  "false" \
  "path=normal startup_included=true metadata_enabled=true"

run_normal_case \
  "html_img_single" \
  "$ROOT/samples/main_process/html/assets/html_img_single.html" \
  "markdown_plus_assets" \
  "false" \
  "true" \
  "path=normal startup_included=true metadata_enabled=false asset_path=output_dir"

run_normal_case \
  "docx_image_alt_title_basic" \
  "$ROOT/samples/main_process/docx/assets/docx_image_alt_title_basic.docx" \
  "markdown_plus_metadata_assets" \
  "true" \
  "true" \
  "path=normal startup_included=true metadata_enabled=true asset_path=output_dir"

run_batch_case \
  "batch_txt_json_small" \
  "false" \
  "path=batch startup_included=true amortization_probe=true"
