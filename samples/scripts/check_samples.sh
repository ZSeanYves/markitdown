#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SAMPLES_DIR="$ROOT/samples/main_process"
EXP_DIR="$SAMPLES_DIR/expected"
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

for fmt in "${FORMATS[@]}"; do
  group_count=$((group_count + 1))
  in_dir="$SAMPLES_DIR/$fmt"
  exp_dir="$EXP_DIR/$fmt"

  if [[ ! -d "$in_dir" ]]; then
    echo "[warn] input dir missing: $in_dir"
    continue
  fi

  mkdir -p "$exp_dir"

  input_bases="$(find "$in_dir" -maxdepth 1 -type f | sort | while read -r path; do
    base="$(basename "$path")"
    if is_noise_file "$base"; then
      continue
    fi
    name="${base%.*}"
    ext="${base##*.}"
    ext_lc="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

    if [[ "$fmt" == "html" ]]; then
      [[ "$ext_lc" =~ ^(html|htm)$ ]] && echo "$name"
    elif [[ "$fmt" == "yaml" ]]; then
      [[ "$ext_lc" =~ ^(yaml|yml)$ ]] && echo "$name"
    elif [[ "$fmt" == "markdown" ]]; then
      [[ "$ext_lc" =~ ^(md|markdown)$ ]] && echo "$name"
    elif [[ "$fmt" == "txt" ]]; then
      [[ "$ext_lc" == "txt" ]] && echo "$name"
    elif [[ "$fmt" == "xml" ]]; then
      [[ "$ext_lc" == "xml" ]] && echo "$name"
    else
      [[ "$ext_lc" == "$fmt" ]] && echo "$name"
    fi
  done | sort -u)"

  all_sample_bases="$(find "$in_dir" -maxdepth 1 -type f | sort | while read -r path; do
    base="$(basename "$path")"
    if is_noise_file "$base"; then
      continue
    fi
    echo "${base%.*}"
  done | sort -u)"

  expected_bases="$(find "$exp_dir" -maxdepth 1 -type f -name '*.md' -print | sort | while read -r path; do
    base="$(basename "$path")"
    echo "${base%.md}"
  done | sort -u)"

  if [[ "$fmt" == "pptx" && $GEN_PPTX_IMAGE_CONTEXT_FAILED -eq 1 ]]; then
    generated_only_bases=$'pptx_image_caption_basic\npptx_image_caption_near_basic\npptx_image_multiple_caption_ambiguous_negative'
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
      if printf '%s\n' "$all_sample_bases" | grep -Fxq "$base"; then
        echo "  [error] expected exists but only non-enrolled input extension found:"
        echo "    - $base"
      else
        echo "  [error] expected exists but input missing:"
        echo "    - $base"
      fi
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

  unknown_files=0
  reference_files=0
  while IFS= read -r path; do
    base="$(basename "$path")"
    if is_noise_file "$base"; then
      continue
    fi
    ext="${base##*.}"
    ext_lc="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

    enrolled=false
    if [[ "$fmt" == "html" ]]; then
      [[ "$ext_lc" =~ ^(html|htm)$ ]] && enrolled=true
    elif [[ "$fmt" == "yaml" ]]; then
      [[ "$ext_lc" =~ ^(yaml|yml)$ ]] && enrolled=true
    elif [[ "$fmt" == "markdown" ]]; then
      [[ "$ext_lc" =~ ^(md|markdown)$ ]] && enrolled=true
    elif [[ "$fmt" == "txt" ]]; then
      [[ "$ext_lc" == "txt" ]] && enrolled=true
    elif [[ "$fmt" == "xml" ]]; then
      [[ "$ext_lc" == "xml" ]] && enrolled=true
    else
      [[ "$ext_lc" == "$fmt" ]] && enrolled=true
    fi

    if [[ "$enrolled" == true ]]; then
      continue
    fi

    if [[ "$ext_lc" == "key" ]]; then
      if [[ $reference_files -eq 0 ]] && bool_enabled "$SAMPLES_VERBOSE"; then
        echo "  [info] reference-only files (excluded from regression):"
      fi
      if bool_enabled "$SAMPLES_VERBOSE"; then
        echo "    - $base"
      fi
      reference_files=$((reference_files + 1))
    else
      if [[ $unknown_files -eq 0 ]]; then
        if [[ "$quiet_integrity" -eq 1 ]]; then
          printf '[%s]\n' "$fmt"
        fi
        echo "  [warn] unsupported sample extensions (not in regression):"
      fi
      echo "    - $base"
      unknown_files=$((unknown_files + 1))
    fi
  done < <(find "$in_dir" -maxdepth 1 -type f | sort)

  if [[ -z "$missing_input" && -z "$missing_expected" && $unknown_files -eq 0 ]] && bool_enabled "$SAMPLES_VERBOSE"; then
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
