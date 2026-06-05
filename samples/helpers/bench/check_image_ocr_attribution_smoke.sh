#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/samples/helpers/shared/tmp_helpers.sh"

TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}/bench/helpers"
TMP_PARENT="$TMP_ROOT/image_ocr_bench"
TMP_DIR=""
CLI_BIN=""
RUNS="${BENCH_ITERATIONS:-3}"

FIXTURE_PATH="$ROOT/samples/fixtures/ocr/tiny_ocr_sample.png"
EXPECTED_PATH="$ROOT/samples/fixtures/ocr/tiny_ocr_sample.expected.txt"
EXPECTED_LINES=()

usage() {
  cat <<'EOF'
usage: bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh [--help] [--runs N]

Read-only image OCR attribution smoke using the public native CLI.

Requirements:
  * prebuilt native CLI
  * local tesseract executable
  * local eng tessdata
  * recommended command:
      moon build cli --target native

Environment overrides:
  MARKITDOWN_CLI      path to prebuilt native cli.exe
  BENCH_ITERATIONS    measured runs per case (default: 3)
  MARKITDOWN_TMP_DIR  override temp root (default: .tmp)

Output columns:
  case mode runs median_ms min_ms max_ms input output_bytes notes

Notes:
  * this helper is separate from normal product-path attribution smoke
  * this helper does not build binaries internally
  * this helper skips cleanly when tesseract or eng tessdata is unavailable
  * results are same-machine directional only
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

make_tmp_dir() {
  mkdir -p "$TMP_PARENT"
  TMP_DIR="$(mktemp -d "$TMP_PARENT/check_image_ocr_attribution_smoke.XXXXXX")"
}

tesseract_available() {
  command -v tesseract >/dev/null 2>&1
}

tesseract_has_lang() {
  local lang="$1"
  tesseract --list-langs 2>/dev/null | grep -Fxq "$lang"
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

assert_expected_text() {
  local path="$1"
  local expected_line
  for expected_line in "${EXPECTED_LINES[@]}"; do
    [[ -n "$expected_line" ]] || continue
    grep -Fq -- "$expected_line" "$path" || {
      echo "expected OCR output to contain: $expected_line" >&2
      exit 1
    }
  done
}

run_cli_timed_capture() {
  local stdout_path="$1"
  local stderr_path="$2"
  shift 2

  local start_us end_us elapsed_us status
  status=0
  start_us="$(now_us)"
  "$@" >"$stdout_path" 2>"$stderr_path" || status=$?
  if [[ "$status" -ne 0 ]]; then
    if [[ -s "$stderr_path" ]]; then
      cat "$stderr_path" >&2
    fi
    if [[ -s "$stdout_path" ]]; then
      cat "$stdout_path" >&2
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

run_mode() {
  local mode="$1"
  shift

  local -a values=()
  local iter elapsed_us stdout_path stderr_path output_bytes
  output_bytes="0"

  for ((iter = 1; iter <= RUNS; iter++)); do
    stdout_path="$TMP_DIR/$mode.iter-$iter.stdout"
    stderr_path="$TMP_DIR/$mode.iter-$iter.stderr"
    elapsed_us="$(run_cli_timed_capture "$stdout_path" "$stderr_path" "$CLI_BIN" "$@")" || {
      echo "image OCR attribution smoke failed for mode: $mode" >&2
      exit 1
    }
    assert_expected_text "$stdout_path"
    values+=("$elapsed_us")
    output_bytes="$(file_size_bytes "$stdout_path")"
  done

  report_case \
    "tiny_ocr_sample" \
    "$mode" \
    "$FIXTURE_PATH" \
    "$output_bytes" \
    "tesseract_external tiny_fixture same_machine_directional" \
    "${values[@]}"
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

if [[ ! -f "$FIXTURE_PATH" ]]; then
  echo "missing OCR fixture: $FIXTURE_PATH" >&2
  exit 1
fi

if [[ ! -f "$EXPECTED_PATH" ]]; then
  echo "missing OCR expected text: $EXPECTED_PATH" >&2
  exit 1
fi

while IFS= read -r expected_line || [[ -n "$expected_line" ]]; do
  EXPECTED_LINES+=("$expected_line")
done < "$EXPECTED_PATH"

resolve_cli_path

if ! tesseract_available; then
  echo "IMAGE OCR ATTRIBUTION SMOKE SKIPPED: tesseract not installed"
  exit 0
fi

if ! tesseract_has_lang eng; then
  echo "IMAGE OCR ATTRIBUTION SMOKE SKIPPED: eng tessdata not installed"
  exit 0
fi

make_tmp_dir

printf 'case\tmode\truns\tmedian_ms\tmin_ms\tmax_ms\tinput\toutput_bytes\tnotes\n'

run_mode "image_auto" "$FIXTURE_PATH"
run_mode "image_ocr_lang_eng" "$FIXTURE_PATH" "--ocr-lang" "eng"
run_mode "image_explicit_ocr" "$FIXTURE_PATH" "--ocr"
