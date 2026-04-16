#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAMPLES_DIR="$ROOT/samples"
EXP_DIR="$SAMPLES_DIR/expected"
GEN_SCRIPT="$SAMPLES_DIR/generate_hyperlink_binaries.py"
GEN_PPTX_IMAGE_CONTEXT_SCRIPT="$SAMPLES_DIR/generate_image_context_pptx_samples.py"

FORMATS=("docx" "pdf" "xlsx" "html" "pptx")

fail=0

echo "==> sample integrity check"

if [[ -f "$GEN_SCRIPT" ]]; then
  echo "==> generate binary hyperlink samples"
  if ! python3 "$GEN_SCRIPT"; then
    echo "[warn] binary sample generation failed; integrity check may fail for generated cases"
  fi
fi

if [[ -f "$GEN_PPTX_IMAGE_CONTEXT_SCRIPT" ]]; then
  echo "==> generate pptx image-context samples"
  if ! python3 "$GEN_PPTX_IMAGE_CONTEXT_SCRIPT"; then
    echo "[warn] pptx image-context sample generation failed; integrity check may fail for generated cases"
  fi
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

  printf '\n[%s]\n' "$fmt"

  missing_input="$(comm -23 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"
  missing_expected="$(comm -13 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"

  if [[ -n "$missing_input" ]]; then
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
    else
      [[ "$ext_lc" == "$fmt" ]] && enrolled=true
    fi

    if [[ "$enrolled" == true ]]; then
      continue
    fi

    if [[ "$ext_lc" == "key" ]]; then
      if [[ $reference_files -eq 0 ]]; then
        echo "  [info] reference-only files (excluded from regression):"
      fi
      echo "    - $base"
      reference_files=$((reference_files + 1))
    else
      if [[ $unknown_files -eq 0 ]]; then
        echo "  [warn] unsupported sample extensions (not in regression):"
      fi
      echo "    - $base"
      unknown_files=$((unknown_files + 1))
    fi
  done < <(find "$in_dir" -maxdepth 1 -type f | sort)

  if [[ -z "$missing_input" && -z "$missing_expected" && $unknown_files -eq 0 ]]; then
    echo "  [ok] sample/expected enrollment is consistent"
  fi

done

if [[ $fail -ne 0 ]]; then
  printf '\nSAMPLE INTEGRITY CHECK FAILED\n'
  exit 1
fi

printf '\nSAMPLE INTEGRITY CHECK PASSED\n'
