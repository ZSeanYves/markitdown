#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/samples/helpers/tmp_helpers.sh"
source "$ROOT/samples/helpers/validation_helpers.sh"

MANIFEST_PATH="$ROOT/samples/quality_corpus/manifest.tsv"
PRIVATE_MANIFEST_PATH="$ROOT/samples/quality_corpus/private/manifest.local.tsv"
EXTERNAL_MANIFEST_PATH="$ROOT/samples/quality_corpus/external_manifest.local.tsv"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_ROOT="$TMP_ROOT/quality_corpus"
OUTPUT_DIR="$OUT_ROOT/outputs"
SUMMARY_TSV="$OUT_ROOT/summary.tsv"
SUMMARY_MD="$OUT_ROOT/summary.md"
MODE="all"

PUBLIC_HEADER=$'id\tformat\tpath\tsource_type\tlicense_status\tprivacy\tsize_class\tfeatures\texpected_signals\tquality_tier\tnotes'
EXTERNAL_HEADER=$'id\tformat\tpath\tsource_type\tsource_id\tlicense_status\tlicense_review_status\tprivacy\tsize_class\tfeatures\texpected_signals\tquality_tier\toriginal_url\tlocal_cache_path\tnotes'

usage() {
  cat <<'EOF'
usage: ./samples/quality_corpus/check.sh [--public-only | --private-only]

Modes:
  --public-only   run only checked-in public intake rows
  --private-only  run only local private intake rows

Notes:
  * empty public manifest is valid
  * missing private manifest is skipped
  * missing external manifest is skipped
  * non-approved external rows are skipped
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

normalized_text_without_asset_urls() {
  local path="$1"
  python3 - "$path" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = text.replace("\r\n", "\n").replace("\r", "\n")

# Strip markdown image/link target paths and raw URLs before token-length checks.
text = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', r'!\1', text)
text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'\1', text)
text = re.sub(r'https?://\S+', '', text)

sys.stdout.write(text)
PY
}

normalize_public_row() {
  local scope="$1"
  local raw_line="$2"
  local delimiter=$'\x1f'
  local converted="${raw_line//$'\t'/$delimiter}"
  local id format path source_type license_status privacy size_class features expected_signals quality_tier notes
  IFS="$delimiter" read -r id format path source_type license_status privacy size_class features expected_signals quality_tier notes <<< "$converted"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$scope" \
    "$id" \
    "$format" \
    "$path" \
    "$source_type" \
    "" \
    "$license_status" \
    "approved" \
    "$privacy" \
    "$size_class" \
    "$features" \
    "$expected_signals" \
    "$quality_tier" \
    "" \
    "$notes"
}

normalize_external_row() {
  local raw_line="$1"
  local delimiter=$'\x1f'
  local converted="${raw_line//$'\t'/$delimiter}"
  local id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url local_cache_path notes
  IFS="$delimiter" read -r id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url local_cache_path notes <<< "$converted"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "external" \
    "$id" \
    "$format" \
    "$path" \
    "$source_type" \
    "$source_id" \
    "$license_status" \
    "$license_review_status" \
    "$privacy" \
    "$size_class" \
    "$features" \
    "$expected_signals" \
    "$quality_tier" \
    "$original_url" \
    "$notes"
}

manifest_rows_from_file() {
  local manifest_path="$1"
  local scope="$2"
  local expected_header="$3"
  local normalizer="$4"
  [[ -f "$manifest_path" ]] || return 0

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
    "$normalizer" "$scope" "$raw_line"
  done < "$manifest_path"
}

normalize_external_manifest_entry() {
  local _scope="$1"
  local raw_line="$2"
  normalize_external_row "$raw_line"
}

collect_manifest_rows() {
  local rows=()
  if [[ "$MODE" != "private" ]]; then
    while IFS= read -r row; do
      [[ -n "$row" ]] && rows+=("$row")
    done < <(manifest_rows_from_file "$MANIFEST_PATH" "public" "$PUBLIC_HEADER" normalize_public_row)
  fi
  if [[ "$MODE" != "public" && -f "$PRIVATE_MANIFEST_PATH" ]]; then
    while IFS= read -r row; do
      [[ -n "$row" ]] && rows+=("$row")
    done < <(manifest_rows_from_file "$PRIVATE_MANIFEST_PATH" "private" "$PUBLIC_HEADER" normalize_public_row)
  fi
  if [[ "$MODE" != "public" && -f "$EXTERNAL_MANIFEST_PATH" ]]; then
    while IFS= read -r row; do
      [[ -n "$row" ]] && rows+=("$row")
    done < <(manifest_rows_from_file "$EXTERNAL_MANIFEST_PATH" "external" "$EXTERNAL_HEADER" normalize_external_manifest_entry)
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
    contains_all:*)
      local rest="${signal#contains_all:}"
      python3 - "$normalized_text" "$rest" <<'PY'
import sys
text = sys.argv[1]
parts = [p for p in sys.argv[2].split("|") if p]
for part in parts:
    if part not in text:
        raise SystemExit(1)
PY
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
    max_long_token_len:*)
      local limit="${signal#max_long_token_len:}"
      local token_text
      token_text="$(normalized_text_without_asset_urls "$markdown_path")"
      python3 - "$token_text" "$limit" <<'PY'
import re
import sys
text = sys.argv[1]
limit = int(sys.argv[2])
tokens = re.findall(r'\S+', text)
for token in tokens:
    if len(token) > limit:
        raise SystemExit(1)
PY
      ;;
    page_noise_absent:*)
      [[ "$normalized_text" != *"${signal#page_noise_absent:}"* ]]
      ;;
    review_note:*)
      return 0
      ;;
    *)
      echo "unknown quality signal: $signal" >&2
      return 1
      ;;
  esac
}

summary_add() {
  local id="$1"
  local format="$2"
  local scope="$3"
  local quality_tier="$4"
  local status="$5"
  local passed_signals="$6"
  local total_signals="$7"
  local notes="$8"
  SUMMARY_ROWS+=("$id|$format|$scope|$quality_tier|$status|$passed_signals|$total_signals|$notes")
}

run_row() {
  local row="$1"
  local delimiter=$'\x1f'
  local converted="${row//$'\t'/$delimiter}"
  local source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes
  IFS="$delimiter" read -r source_scope id format path source_type source_id license_status license_review_status privacy size_class features expected_signals quality_tier original_url notes <<< "$converted"

  if [[ "$source_scope" == "external" ]]; then
    if [[ "$license_review_status" != "approved" ]]; then
      summary_add "$id" "$format" "$source_scope" "$quality_tier" "skip_license" 0 0 "license_review_status=$license_review_status"
      return
    fi
  fi

  local abs_path="$path"
  if [[ "$abs_path" != /* ]]; then
    abs_path="$ROOT/$abs_path"
  fi

  if [[ ! -f "$abs_path" ]]; then
    case "$source_scope" in
      external)
        summary_add "$id" "$format" "$source_scope" "$quality_tier" "skip_missing_file" 0 0 "external cache file missing"
        ;;
      private)
        summary_add "$id" "$format" "$source_scope" "$quality_tier" "skip_missing_file" 0 0 "private local file missing"
        ;;
      *)
        summary_add "$id" "$format" "$source_scope" "$quality_tier" "fail" 0 0 "input file missing"
        ;;
    esac
    return
  fi

  local row_dir="$OUTPUT_DIR/$id"
  rm -rf "$row_dir"
  mkdir -p "$row_dir"

  local output_md="$row_dir/$id.md"
  if ! run_markitdown_cli normal --with-metadata "$abs_path" "$output_md" >/dev/null 2>&1; then
    summary_add "$id" "$format" "$source_scope" "$quality_tier" "fail" 0 0 "cli conversion failed"
    return
  fi

  local metadata_path="$row_dir/metadata/$id.metadata.json"
  local normalized_text
  normalized_text="$(normalize_text "$output_md")"

  local total_signals=0
  local passed_signals=0
  local failed_details=()
  local review_notes=()
  local signal
  IFS=';' read -r -a signals <<< "$expected_signals"
  for signal in "${signals[@]}"; do
    signal="$(printf '%s' "$signal" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$signal" ]] && continue
    if [[ "$signal" == review_note:* ]]; then
      review_notes+=("${signal#review_note:}")
      continue
    fi
    total_signals=$((total_signals + 1))
    if check_signal "$signal" "$output_md" "$metadata_path" "$row_dir" "$normalized_text"; then
      passed_signals=$((passed_signals + 1))
    else
      failed_details+=("$signal")
    fi
  done

  if [[ "$total_signals" -eq 0 ]]; then
    local note_text="no expected signals configured"
    if [[ "${#review_notes[@]}" -gt 0 ]]; then
      note_text="$note_text; review: ${review_notes[*]}"
    fi
    summary_add "$id" "$format" "$source_scope" "$quality_tier" "skip" 0 0 "$note_text"
    return
  fi

  if [[ "${#failed_details[@]}" -gt 0 ]]; then
    local note_text="failed: ${failed_details[*]}"
    if [[ "${#review_notes[@]}" -gt 0 ]]; then
      note_text="$note_text; review: ${review_notes[*]}"
    fi
    summary_add "$id" "$format" "$source_scope" "$quality_tier" "fail" "$passed_signals" "$total_signals" "$note_text"
    return
  fi

  local note_text="all signals passed"
  if [[ "${#review_notes[@]}" -gt 0 ]]; then
    note_text="$note_text; review: ${review_notes[*]}"
  fi
  summary_add "$id" "$format" "$source_scope" "$quality_tier" "pass" "$passed_signals" "$total_signals" "$note_text"
}

write_summary() {
  local total="$1"
  local passed="$2"
  local failed="$3"
  local skipped="$4"
  local skipped_license="$5"
  local skipped_missing_file="$6"
  local no_manifest_rows="$7"

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
    printf 'SKIPPED_LICENSE\t-\t-\t-\t-\t%s\t-\tskipped because license_review_status was not approved\n' "$skipped_license"
    printf 'SKIPPED_MISSING_FILE\t-\t-\t-\t-\t%s\t-\tskipped because the local cache or private file was missing\n' "$skipped_missing_file"
    printf 'NO_MANIFEST_ROWS\t-\t-\t-\t-\t%s\t-\t1 means no rows selected\n' "$no_manifest_rows"
  } > "$SUMMARY_TSV"

  {
    echo "# Quality Corpus Summary"
    echo
    echo "- total: $total"
    echo "- passed: $passed"
    echo "- failed: $failed"
    echo "- skipped: $skipped"
    echo "- skipped_license: $skipped_license"
    echo "- skipped_missing_file: $skipped_missing_file"
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
  write_summary 0 0 0 0 0 0 1
  echo "QUALITY CORPUS PASSED (no manifest rows selected)"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 0
fi

validation_progress_init "quality_corpus" "${#MANIFEST_ROWS[@]}"

for row in "${MANIFEST_ROWS[@]}"; do
  IFS=$'\t' read -r source_scope id _ <<< "$row"
  validation_progress_step "$id"
  run_row "$row"
done

validation_progress_done

total_rows=0
passed_rows=0
failed_rows=0
skipped_rows=0
skipped_license_rows=0
skipped_missing_file_rows=0

for row in "${SUMMARY_ROWS[@]-}"; do
  [[ -z "$row" ]] && continue
  total_rows=$((total_rows + 1))
  IFS='|' read -r _ _ _ _ status _ _ _ <<< "$row"
  case "$status" in
    pass)
      passed_rows=$((passed_rows + 1))
      ;;
    fail)
      failed_rows=$((failed_rows + 1))
      ;;
    skip)
      skipped_rows=$((skipped_rows + 1))
      ;;
    skip_license)
      skipped_rows=$((skipped_rows + 1))
      skipped_license_rows=$((skipped_license_rows + 1))
      ;;
    skip_missing_file)
      skipped_rows=$((skipped_rows + 1))
      skipped_missing_file_rows=$((skipped_missing_file_rows + 1))
      ;;
  esac
done

write_summary "$total_rows" "$passed_rows" "$failed_rows" "$skipped_rows" "$skipped_license_rows" "$skipped_missing_file_rows" 0

if [[ "$failed_rows" -ne 0 ]]; then
  echo "QUALITY CORPUS FAILED"
  echo "summary: $SUMMARY_TSV"
  echo "report: $SUMMARY_MD"
  exit 1
fi

echo "QUALITY CORPUS PASSED ($total_rows rows; $skipped_rows skipped)"
echo "summary: $SUMMARY_TSV"
echo "report: $SUMMARY_MD"
