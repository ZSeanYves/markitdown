#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SAMPLES_DIR="$ROOT/samples/main_process"
GEN_PPTX_IMAGE_CONTEXT_FAILED=0
SAMPLES_VERBOSE="${SAMPLES_VERBOSE:-${VERBOSE:-0}}"

FORMATS=("docx" "pdf" "xlsx" "html" "pptx" "csv" "tsv" "txt" "xml" "json" "yaml" "markdown" "zip" "epub")

fail=0
group_count=0
quiet_integrity=0

bool_enabled() {
  local raw="${1-}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if bool_enabled "${SAMPLES_QUIET_INTEGRITY:-0}"; then
  quiet_integrity=1
fi

if [[ "$quiet_integrity" -eq 0 ]]; then
  echo "==> sample integrity check"
fi

is_noise_file() {
  local base="$1"
  [[ "$base" == .* ]] && return 0
  [[ "$base" == *~ ]] && return 0
  [[ "$base" == *.swp ]] && return 0
  [[ "$base" == *.tmp ]] && return 0
  return 1
}

discover_inputs() {
  local fmt="$1"
  local in_dir="$SAMPLES_DIR/$fmt"
  case "$fmt" in
    docx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.docx" -print ;;
    pdf) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.pdf" -print ;;
    xlsx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.xlsx" -print ;;
    pptx) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.pptx" -print ;;
    html) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.html" -o -name "*.htm" \) -print ;;
    csv) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.csv" -print ;;
    tsv) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.tsv" -print ;;
    txt) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.txt" -print ;;
    xml) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.xml" -print ;;
    json) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.json" -print ;;
    yaml) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.yaml" -o -name "*.yml" \) -print ;;
    markdown) find "$in_dir" -path "$in_dir/expected" -prune -o -type f \( -name "*.md" -o -name "*.markdown" \) -print ;;
    zip) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.zip" -print ;;
    epub) find "$in_dir" -path "$in_dir/expected" -prune -o -type f -name "*.epub" -print ;;
    *) return 0 ;;
  esac
}

for fmt in "${FORMATS[@]}"; do
  group_count=$((group_count + 1))
  in_dir="$SAMPLES_DIR/$fmt"
  exp_dir="$in_dir/expected"

  if [[ ! -d "$in_dir" ]]; then
    echo "[warn] input dir missing: $in_dir"
    continue
  fi

  mkdir -p "$exp_dir"

  input_bases="$(discover_inputs "$fmt" | sort | while read -r path; do
    rel="${path#$in_dir/}"
    base="$(basename "$rel")"
    if is_noise_file "$base"; then
      continue
    fi
    echo "${rel%.*}"
  done | sort -u)"

  expected_bases="$(find "$exp_dir" -type f -name '*.md' -print | sort | while read -r path; do
    rel="${path#$exp_dir/}"
    if [[ "$rel" == reference/* ]]; then
      continue
    fi
    echo "${rel%.md}"
  done | sort -u)"

  if [[ "$fmt" == "pptx" && $GEN_PPTX_IMAGE_CONTEXT_FAILED -eq 1 ]]; then
    generated_only_bases=$'metadata/pptx_image_caption_basic\nmetadata/pptx_image_caption_near_basic\nmetadata/pptx_image_multiple_caption_ambiguous_negative'
    input_bases="$(comm -23 <(printf '%s\n' "$input_bases" | sed '/^$/d' | sort -u) <(printf '%s\n' "$generated_only_bases" | sed '/^$/d' | sort -u))"
    expected_bases="$(comm -23 <(printf '%s\n' "$expected_bases" | sed '/^$/d' | sort -u) <(printf '%s\n' "$generated_only_bases" | sed '/^$/d' | sort -u))"
  fi

  if bool_enabled "$SAMPLES_VERBOSE"; then
    printf '\n[%s]\n' "$fmt"
  fi

  missing_input="$(comm -23 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"
  missing_expected="$(comm -13 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"

  if [[ -n "$missing_input" ]]; then
    if [[ "$quiet_integrity" -eq 1 ]]; then
      printf '[%s]\n' "$fmt"
    fi
    while IFS= read -r base; do
      [[ -z "$base" ]] && continue
      echo "  [error] expected exists but input missing:"
      echo "    - $base"
      fail=1
    done <<< "$missing_input"
  fi

  if [[ -n "$missing_expected" ]]; then
    if [[ "$quiet_integrity" -eq 1 && -z "$missing_input" ]]; then
      printf '[%s]\n' "$fmt"
    fi
    echo "  [error] input exists but expected missing:"
    while IFS= read -r base; do
      [[ -z "$base" ]] && continue
      echo "    - $base"
    done <<< "$missing_expected"
    fail=1
  fi

  if [[ -z "$missing_input" && -z "$missing_expected" ]] && bool_enabled "$SAMPLES_VERBOSE"; then
    echo "  [ok] sample/expected enrollment is consistent"
  fi
done

if [[ $fail -ne 0 ]]; then
  printf '\nSAMPLE INTEGRITY CHECK FAILED\n'
  exit 1
fi

if bool_enabled "$SAMPLES_VERBOSE"; then
  printf '\nSAMPLE INTEGRITY CHECK PASSED\n'
else
  printf 'SAMPLE INTEGRITY CHECK PASSED (%s groups)\n' "$group_count"
fi
