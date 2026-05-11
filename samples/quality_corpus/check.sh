#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"

MANIFEST_PATH="$ROOT/samples/quality_corpus/manifest.tsv"
PRIVATE_MANIFEST_PATH="$ROOT/samples/quality_corpus/private/manifest.local.tsv"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_ROOT="$TMP_ROOT/quality_corpus"
OUTPUT_DIR="$OUT_ROOT/outputs"
SUMMARY_TSV="$OUT_ROOT/summary.tsv"
SUMMARY_MD="$OUT_ROOT/summary.md"
MODE="all"

usage() {
  cat <<'EOF'
usage: ./samples/quality_corpus/check.sh [--public-only | --private-only]

Modes:
  --public-only   run only checked-in public intake rows
  --private-only  run only local private intake rows

Notes:
  * empty public manifest is valid
  * missing private manifest is skipped
  * missing external/private files are recorded as skipped when appropriate
  * this is a signal-level intake checker, not an exact-output regression gate
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --public-only)
      MODE="public"
      ;;
    --private-only)
      MODE="private"
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
  shift
done

mkdir -p "$OUTPUT_DIR"

resolve_markitdown_cli

trim_cr() {
  local value="${1-}"
  value="${value%$'\r'}"
  printf '%s' "$value"
}

normalize_text() {
  local path="$1"
  python3 - "$path" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = text.replace("\r\n", "\n").replace("\r", "\n")
sys.stdout.write(text)
PY
}

manifest_rows_from_file() {
  local manifest_path="$1"
  local source_scope="$2"
  [[ -f "$manifest_path" ]] || return 0

  local expected_header=$'id\tformat\tpath\tsource_type\tlicense_status\tprivacy\tsize_class\tfeatures\texpected_signals\tquality_tier\tnotes'
  local line_no=0
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    raw_line="$(trim_cr "$raw_line")"
    line_no=$((line_no + 1))
    if [[ "$line_no" -eq 1 ]]; then
      if [[ "$raw_line" != "$expected_header" ]]; then
        echo "quality_corpus manifest header mismatch: $manifest_path" >&2
        echo "expected: $expected_header" >&2
        echo "actual:   $raw_line" >&2
        exit 1
      fi
      continue
    fi
    [[ -z "$raw_line" ]] && continue
    [[ "${raw_line#\#}" != "$raw_line" ]] && continue
    printf '%s\t%s\n' "$source_scope" "$raw_line"
  done < "$manifest_path"
}

collect_manifest_rows() {
  local rows=()
  if [[ "$MODE" != "private" ]]; then
    while IFS= read -r row; do
      [[ -n "$row" ]] && rows+=("$row")
    done < <(manifest_rows_from_file "$MANIFEST_PATH" "public")
  fi
  if [[ "$MODE" != "public" && -f "$PRIVATE_MANIFEST_PATH" ]]; then
    while IFS= read -r row; do
      [[ -n "$row" ]] && rows+=("$row")
    done < <(manifest_rows_from_file "$PRIVATE_MANIFEST_PATH" "private")
  fi
  if [[ "${#rows[@]}" -eq 0 ]]; then
    return 0
  fi
  printf '%s\n' "${rows[@]}"
}

count_assets_on_disk() {
  local out_dir="$1"
  if [[ ! -d "$out_dir/assets" ]]; then
    printf '0'
    return
  fi
  find "$out_dir/assets" -type f | wc -l | tr -d '[:space:]'
}

count_short_lines() {
  local path="$1"
  local threshold=40
  awk -v threshold="$threshold" '
    {
      line=$0
      gsub(/[[:space:]]+$/, "", line)
      if (line != "" && length(line) <= threshold) {
        count++
      }
    }
    END { print count + 0 }
  ' "$path"
}

check_signal() {
  local signal="$1"
  local markdown_path="$2"
  local metadata_path="$3"
  local output_dir="$4"
  local normalized_text="$5"

  case "$signal" in
    no_empty_output)
      [[ -n "${normalized_text//[$'\n\t\r ']}" ]]
      ;;
    contains:*)
      [[ "$normalized_text" == *"${signal#contains:}"* ]]
      ;;
    not_contains:*)
      [[ "$normalized_text" != *"${signal#not_contains:}"* ]]
      ;;
    heading_marker:*)
      local needle="${signal#heading_marker:}"
      grep -Eq "^[[:space:]]*#+[[:space:]]+.*${needle//\//\\/}.*$" "$markdown_path"
      ;;
    table_marker)
      grep -Eq '^[[:space:]]*\|.*\|[[:space:]]*$' "$markdown_path"
      ;;
    image_ref)
      grep -Eq '!\[[^]]*\]\([^)]*\)' "$markdown_path"
      ;;
    link_ref)
      grep -Eq '\[[^]]+\]\([^)]*\)' "$markdown_path"
      ;;
    metadata_file)
      [[ -f "$metadata_path" ]]
      ;;
    asset_count_min:*)
      local min_count="${signal#asset_count_min:}"
      local actual_count
      actual_count="$(count_assets_on_disk "$output_dir")"
      [[ "$actual_count" =~ ^[0-9]+$ ]] || return 1
      (( actual_count >= min_count ))
      ;;
    order:*)
      local rest="${signal#order:}"
      python3 - "$normalized_text" "$rest" <<'PY'
import sys
text = sys.argv[1]
parts = [p for p in sys.argv[2].split("|") if p]
pos = -1
for part in parts:
    nxt = text.find(part, pos + 1)
    if nxt < 0:
        raise SystemExit(1)
    pos = nxt
PY
      ;;
    line_fragmentation_max:*)
      local limit="${signal#line_fragmentation_max:}"
      local actual
      actual="$(count_short_lines "$markdown_path")"
      [[ "$actual" =~ ^[0-9]+$ ]] || return 1
      (( actual <= limit ))
      ;;
    page_noise_absent:*)
      [[ "$normalized_text" != *"${signal#page_noise_absent:}"* ]]
      ;;
    *)
      echo "unknown quality signal: $signal" >&2
      return 1
      ;;
  esac
}

should_skip_missing_path() {
  local source_type="$1"
  local privacy="$2"
  case "$source_type" in
    external_manual|private_local|public_dataset|tool_fixture|self_real)
      if [[ "$privacy" == "private_local" || "$source_type" == "external_manual" || "$source_type" == "private_local" ]]; then
        return 0
      fi
      ;;
  esac
  return 1
}

run_row() {
  local source_scope="$1"
  local row="$2"
  local delimiter=$'\x1f'
  local converted="${row//$'\t'/$delimiter}"
  local id format path source_type license_status privacy size_class features expected_signals quality_tier notes
  IFS="$delimiter" read -r id format path source_type license_status privacy size_class features expected_signals quality_tier notes <<< "$converted"

  local abs_path="$path"
  if [[ "$abs_path" != /* ]]; then
    abs_path="$ROOT/$abs_path"
  fi

  if [[ ! -f "$abs_path" ]]; then
    if should_skip_missing_path "$source_type" "$privacy"; then
      SUMMARY_ROWS+=("$id|$format|$source_scope|$quality_tier|skip|0|0|input file missing but allowed to skip")
    else
      SUMMARY_ROWS+=("$id|$format|$source_scope|$quality_tier|fail|0|0|input file missing")
    fi
    return
  fi

  local row_dir="$OUTPUT_DIR/$id"
  rm -rf "$row_dir"
  mkdir -p "$row_dir"

  local output_md="$row_dir/$id.md"
  if ! run_markitdown_cli normal --with-metadata "$abs_path" "$output_md" >/dev/null 2>&1; then
    SUMMARY_ROWS+=("$id|$format|$source_scope|$quality_tier|fail|0|0|cli conversion failed")
    return
  fi

  local metadata_path="$row_dir/metadata/$id.metadata.json"
  local normalized_text
  normalized_text="$(normalize_text "$output_md")"

  local total_signals=0
  local passed_signals=0
  local failed_details=()
  local signal
  IFS=';' read -r -a signals <<< "$expected_signals"
  for signal in "${signals[@]}"; do
    signal="$(printf '%s' "$signal" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$signal" ]] && continue
    total_signals=$((total_signals + 1))
    if check_signal "$signal" "$output_md" "$metadata_path" "$row_dir" "$normalized_text"; then
      passed_signals=$((passed_signals + 1))
    else
      failed_details+=("$signal")
    fi
  done

  if [[ "$total_signals" -eq 0 ]]; then
    SUMMARY_ROWS+=("$id|$format|$source_scope|$quality_tier|skip|0|0|no expected signals configured")
    return
  fi

  local status="pass"
  local notes_out="all signals passed"
  if [[ "${#failed_details[@]}" -gt 0 ]]; then
    status="fail"
    notes_out="failed: ${failed_details[*]}"
  fi
  SUMMARY_ROWS+=("$id|$format|$source_scope|$quality_tier|$status|$passed_signals|$total_signals|$notes_out")
}

write_summary() {
  local total="$1"
  local passed="$2"
  local failed="$3"
  local skipped="$4"
  local no_manifest_rows="$5"

  mkdir -p "$OUT_ROOT"
  {
    printf 'id\tformat\tscope\tquality_tier\tstatus\tpassed_signals\ttotal_signals\tnotes\n'
    local row
    for row in "${SUMMARY_ROWS[@]-}"; do
      [[ -z "$row" ]] && continue
      printf '%s\n' "${row//|/$'\t'}"
    done
    printf 'TOTAL\t-\t-\t-\t-\t%s\t%s\ttotal rows processed\n' "$passed" "$total"
    printf 'PASSED\t-\t-\t-\t-\t%s\t-\tpassed rows\n' "$passed"
    printf 'FAILED\t-\t-\t-\t-\t%s\t-\tfailed rows\n' "$failed"
    printf 'SKIPPED\t-\t-\t-\t-\t%s\t-\tskipped rows\n' "$skipped"
    printf 'NO_MANIFEST_ROWS\t-\t-\t-\t-\t%s\t-\t1 means no rows selected\n' "$no_manifest_rows"
  } > "$SUMMARY_TSV"

  {
    echo "# Quality Corpus Summary"
    echo
    echo "- total: $total"
    echo "- passed: $passed"
    echo "- failed: $failed"
    echo "- skipped: $skipped"
    echo "- no_manifest_rows: $no_manifest_rows"
    echo
    if [[ "${#SUMMARY_ROWS[@]-0}" -eq 0 ]]; then
      echo "No manifest rows selected."
    else
      echo "| ID | Format | Scope | Tier | Status | Passed | Total | Notes |"
      echo "| --- | --- | --- | --- | --- | ---: | ---: | --- |"
      local row
      for row in "${SUMMARY_ROWS[@]-}"; do
        [[ -z "$row" ]] && continue
        IFS='|' read -r id format scope tier status passed_count total_count notes_out <<< "$row"
        echo "| $id | $format | $scope | $tier | $status | $passed_count | $total_count | $notes_out |"
      done
    fi
  } > "$SUMMARY_MD"
}

SUMMARY_ROWS=()
MANIFEST_ROWS=()
while IFS= read -r row; do
  [[ -n "$row" ]] && MANIFEST_ROWS+=("$row")
done < <(collect_manifest_rows)

if [[ "${#MANIFEST_ROWS[@]}" -eq 0 ]]; then
  write_summary 0 0 0 0 1
  echo "QUALITY CORPUS PASSED (no manifest rows selected)"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 0
fi

validation_progress_init "quality_corpus" "${#MANIFEST_ROWS[@]}"

for row in "${MANIFEST_ROWS[@]}"; do
  IFS=$'\t' read -r source_scope id _ <<< "$row"
  validation_progress_step "$id"
  run_row "$source_scope" "${row#*$'\t'}"
done

validation_progress_done

total_rows=${#SUMMARY_ROWS[@]}
passed_rows=0
failed_rows=0
skipped_rows=0
for row in "${SUMMARY_ROWS[@]}"; do
  IFS='|' read -r _ _ _ _ status _ _ _ <<< "$row"
  case "$status" in
    pass) passed_rows=$((passed_rows + 1)) ;;
    fail) failed_rows=$((failed_rows + 1)) ;;
    skip) skipped_rows=$((skipped_rows + 1)) ;;
  esac
done

write_summary "$total_rows" "$passed_rows" "$failed_rows" "$skipped_rows" 0

if [[ "$failed_rows" -ne 0 ]]; then
  echo "QUALITY CORPUS FAILED"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 1
fi

echo "QUALITY CORPUS PASSED ($total_rows rows; $skipped_rows skipped)"
echo "summary: $SUMMARY_TSV"
echo "report: $SUMMARY_MD"
