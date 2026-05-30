#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUALITY_CHECK="$ROOT/samples/helpers/quality/check.sh"
QUALITY_LAB_ROOT="${MARKITDOWN_QUALITY_LAB:-$ROOT/markitdown-quality-lab}"
QUALITY_CORPUS_ROOT="$QUALITY_LAB_ROOT/external_quality"
QUALITY_MANIFEST_PATH="$QUALITY_CORPUS_ROOT/_quality_rows_staging/manifest.tsv"
QUALITY_TMP_ROOT="${QUALITY_TMP_ROOT:-$ROOT/.tmp/quality}"

usage() {
  cat <<'EOF'
usage: bash ./samples/check_quality.sh [--format FORMAT] [--help]

Run the external quality validation entrypoint.

Default behavior:
  * runs only the external quality corpus from markitdown-quality-lab
  * expects:
      markitdown-quality-lab/external_quality/
      markitdown-quality-lab/external_quality/_quality_rows_staging/manifest.tsv
  * does not fall back to repo-local quality rows

Examples:
  bash ./samples/check_quality.sh
  bash ./samples/check_quality.sh --format pdf

If the external quality corpus is not present, clone it with:
  git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
EOF
}

display_path() {
  local path="$1"
  if [[ "$path" == "$ROOT" ]]; then
    printf '.'
  elif [[ "$path" == "$ROOT/"* ]]; then
    printf '%s' "${path#$ROOT/}"
  else
    printf '%s' "$path"
  fi
}

print_missing_corpus() {
  local missing_path="$1"
  echo "EXTERNAL QUALITY CORPUS NOT FOUND" >&2
  echo >&2
  echo "* expected: $(display_path "$QUALITY_CORPUS_ROOT")/" >&2
  echo "* missing: $(display_path "$missing_path")" >&2
  echo "* clone/place markitdown-quality-lab in the repo root" >&2
  echo "* clone: git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab" >&2
  echo "* local-only validation: bash samples/check.sh" >&2
}

summary_value() {
  local label="$1"
  local summary_path="$2"
  python3 - "$label" "$summary_path" <<'PY'
import csv
import sys

label, path = sys.argv[1:]
with open(path, newline="", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter="\t")
    next(reader, None)
    for row in reader:
        if row and row[0] == label:
            value = row[5] if len(row) > 5 else ""
            print(value if value else "0")
            break
    else:
        print("0")
PY
}

FILTER_FORMAT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      [[ $# -ge 2 ]] || {
        echo "missing value for --format" >&2
        usage >&2
        exit 1
      }
      FILTER_FORMAT="$2"
      shift 2
      ;;
    -h|--help)
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

RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_LABEL="all"
if [[ -n "$FILTER_FORMAT" ]]; then
  RUN_LABEL="$FILTER_FORMAT"
fi
QUALITY_RUN_ID="${QUALITY_RUN_ID:-${RUN_LABEL}-${RUN_STAMP}-$$}"
QUALITY_TMP_DIR="${QUALITY_TMP_DIR:-$QUALITY_TMP_ROOT/runs/$QUALITY_RUN_ID}"
QUALITY_CLI_TMP_DIR="${QUALITY_CLI_TMP_DIR:-$QUALITY_TMP_DIR/workspace}"
SUMMARY_PATH="$QUALITY_TMP_DIR/summary.tsv"
RUN_LOG_PATH="$QUALITY_TMP_DIR/entrypoint.log"

if [[ ! -d "$QUALITY_LAB_ROOT" ]]; then
  print_missing_corpus "$QUALITY_LAB_ROOT"
  exit 1
fi

if [[ ! -d "$QUALITY_CORPUS_ROOT" ]]; then
  print_missing_corpus "$QUALITY_CORPUS_ROOT"
  exit 1
fi

if [[ ! -f "$QUALITY_MANIFEST_PATH" ]]; then
  print_missing_corpus "$QUALITY_MANIFEST_PATH"
  exit 1
fi

declare -a runner_args=(
  --private-only
  --require-lab
  --corpus-root "$QUALITY_CORPUS_ROOT"
  --lab-manifest "$QUALITY_MANIFEST_PATH"
)
if [[ -n "$FILTER_FORMAT" ]]; then
  runner_args+=(--format "$FILTER_FORMAT")
fi

mkdir -p "$QUALITY_TMP_DIR"

set +e
env \
  QUALITY_RUN_ID="$QUALITY_RUN_ID" \
  QUALITY_TMP_ROOT="$QUALITY_TMP_ROOT" \
  QUALITY_TMP_DIR="$QUALITY_TMP_DIR" \
  MARKITDOWN_CLI_TMP_DIR="$QUALITY_CLI_TMP_DIR" \
  MARKITDOWN_QUALITY_LAB="$QUALITY_LAB_ROOT" \
  bash "$QUALITY_CHECK" "${runner_args[@]}" >"$RUN_LOG_PATH" 2>&1
status=$?
set -e

rows="0"
failed="0"
skipped="0"
expected_fail="0"
if [[ -f "$SUMMARY_PATH" ]]; then
  rows="$(summary_value "TOTAL" "$SUMMARY_PATH")"
  failed="$(summary_value "FAILED" "$SUMMARY_PATH")"
  skipped="$(summary_value "SKIPPED" "$SUMMARY_PATH")"
  expected_fail="$(summary_value "EXPECTED_FAIL" "$SUMMARY_PATH")"
fi

format_label="all"
if [[ -n "$FILTER_FORMAT" ]]; then
  format_label="$FILTER_FORMAT"
fi

if [[ "$status" -ne 0 ]]; then
  echo "EXTERNAL QUALITY CHECK FAILED"
  echo
  echo "* corpus: $(display_path "$QUALITY_CORPUS_ROOT")"
  echo "* format: $format_label"
  echo "* rows: $rows"
  echo "* failed: $failed"
  echo "* skipped: $skipped"
  echo "* expected_fail: $expected_fail"
  echo "* summary: $(display_path "$SUMMARY_PATH")"
  echo "* log: $(display_path "$RUN_LOG_PATH")"
  exit "$status"
fi

echo "EXTERNAL QUALITY CHECK PASSED"
echo
echo "* corpus: $(display_path "$QUALITY_CORPUS_ROOT")"
echo "* format: $format_label"
echo "* rows: $rows"
echo "* failed: $failed"
echo "* skipped: $skipped"
echo "* expected_fail: $expected_fail"
echo "* summary: $(display_path "$SUMMARY_PATH")"
