#!/usr/bin/env bash

count_non_hidden_files() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -maxdepth 1 -type f ! -name '.*' | wc -l | tr -d '[:space:]'
}

count_expected_markdown_cases() {
  local fmt="$1"
  local dir="$SAMPLES_DIR/$fmt/expected/markdown"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -type f -name '*.md' | wc -l | tr -d '[:space:]'
}

count_expected_ocr_cases() {
  local fmt="$1"
  local dir="$SAMPLES_DIR/$fmt/expected/ocr"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -type f -name '*.md' | wc -l | tr -d '[:space:]'
}

count_expected_rag_cases() {
  local fmt="$1"
  local dir="$SAMPLES_DIR/$fmt/expected/rag"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -type f -name '*.rag.json' | wc -l | tr -d '[:space:]'
}

count_expected_assets_cases() {
  local fmt="$1"
  local dir="$SAMPLES_DIR/$fmt/expected/assets"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]'
}

count_quality_manifest_rows() {
  local fmt="$1"
  local manifest="$ROOT/samples/helpers/quality/manifest.tsv"
  if [[ ! -f "$manifest" ]]; then
    printf '0'
    return
  fi
  awk -F '\t' -v fmt="$fmt" '
    NR == 1 { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    $2 == fmt { count++ }
    END { print count + 0 }
  ' "$manifest"
}

count_quality_comparison_reports() {
  local fmt="$1"
  local dir="$ROOT/docs/quality-comparisons"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -maxdepth 1 -type f -name "${fmt}*.md" | wc -l | tr -d '[:space:]'
}

inventory_list() {
  local fmt
  printf 'format\tmain_markdown\tmain_rag\tmain_assets\tmain_ocr\texpected_markdown\texpected_rag\texpected_assets\texpected_ocr\tfixtures\tquality_records\tquality_intake_public\n'
  while IFS= read -r fmt; do
    [[ -z "$fmt" ]] && continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$fmt" \
      "$(count_non_hidden_files "$SAMPLES_DIR/$fmt/markdown")" \
      "$(count_non_hidden_files "$SAMPLES_DIR/$fmt/rag")" \
      "$(count_non_hidden_files "$SAMPLES_DIR/$fmt/assets")" \
      "$(count_non_hidden_files "$SAMPLES_DIR/$fmt/ocr")" \
      "$(count_expected_markdown_cases "$fmt")" \
      "$(count_expected_rag_cases "$fmt")" \
      "$(count_expected_assets_cases "$fmt")" \
      "$(count_expected_ocr_cases "$fmt")" \
      "$(count_non_hidden_files "$ROOT/samples/fixtures/$fmt")" \
      "$(count_quality_comparison_reports "$fmt")" \
      "$(count_quality_manifest_rows "$fmt")"
  done < <(sample_inventory_formats)
}

sample_integrity_is_noise_file() {
  local base="$1"
  [[ "$base" == .* ]] && return 0
  [[ "$base" == *~ ]] && return 0
  [[ "$base" == *.swp ]] && return 0
  [[ "$base" == *.tmp ]] && return 0
  return 1
}

sample_integrity_discover_inputs() {
  local fmt="$1"
  local lane="$2"
  local in_dir="$SAMPLES_DIR/$fmt/$lane"
  if [[ ! -d "$in_dir" ]]; then
    return 0
  fi
  find "$in_dir" -type f ! -name '.*' ! -path '*/img/*' | sort
}

sample_integrity_expected_bases() {
  local fmt="$1"
  local lane="$2"
  local exp_dir="$SAMPLES_DIR/$fmt/expected/$lane"
  if [[ ! -d "$exp_dir" ]]; then
    return 0
  fi
  case "$lane" in
    markdown)
      find "$exp_dir" -type f -name '*.md' -print | sort | while read -r path; do
        rel="${path#$exp_dir/}"
        echo "${rel%.md}"
      done | sort -u
      ;;
    rag)
      find "$exp_dir" -type f -name '*.rag.json' -print | sort | while read -r path; do
        rel="${path#$exp_dir/}"
        echo "${rel%.rag.json}"
      done | sort -u
      ;;
    assets)
      find "$exp_dir" -mindepth 1 -maxdepth 1 -type d -print | sort | while read -r path; do
        rel="${path#$exp_dir/}"
        echo "$rel"
      done | sort -u
      ;;
    ocr)
      find "$exp_dir" -type f -name '*.md' -print | sort | while read -r path; do
        rel="${path#$exp_dir/}"
        echo "${rel%.md}"
      done | sort -u
      ;;
  esac
}

check_sample_inventory_integrity() {
  local formats=("docx" "pdf" "xlsx" "html" "pptx" "ocr" "csv" "tsv" "txt" "xml" "json" "jsonl" "ndjson" "yaml" "toml" "markdown" "zip" "epub")
  local lanes=("markdown" "rag" "assets" "ocr")
  local fail=0 quiet_integrity=0 fmt lane in_dir exp_dir input_bases expected_bases missing_input missing_expected

  if validation_bool_enabled "${SAMPLES_QUIET_INTEGRITY:-0}"; then
    quiet_integrity=1
  fi

  if [[ "$quiet_integrity" -eq 0 ]]; then
    echo "==> sample integrity check"
  fi

  for fmt in "${formats[@]}"; do
    for lane in "${lanes[@]}"; do
      in_dir="$SAMPLES_DIR/$fmt/$lane"
      exp_dir="$SAMPLES_DIR/$fmt/expected/$lane"

      if [[ ! -d "$in_dir" && ! -d "$exp_dir" ]]; then
        continue
      fi

      input_bases="$(sample_integrity_discover_inputs "$fmt" "$lane" | while read -r path; do
        [[ -z "$path" ]] && continue
        rel="${path#$in_dir/}"
        base="$(basename "$rel")"
        if sample_integrity_is_noise_file "$base"; then
          continue
        fi
        echo "${rel%.*}"
      done | sort -u)"

      expected_bases="$(sample_integrity_expected_bases "$fmt" "$lane")"

      missing_input="$(comm -23 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"
      missing_expected="$(comm -13 <(printf '%s\n' "$expected_bases" | sed '/^$/d') <(printf '%s\n' "$input_bases" | sed '/^$/d'))"

      if [[ -n "$missing_input" || -n "$missing_expected" ]]; then
        if [[ "$quiet_integrity" -eq 1 ]]; then
          printf '[%s/%s]\n' "$fmt" "$lane"
        else
          printf '\n[%s/%s]\n' "$fmt" "$lane"
        fi
      fi

      if [[ -n "$missing_input" ]]; then
        while IFS= read -r base; do
          [[ -z "$base" ]] && continue
          echo "  [error] expected exists but input missing:"
          echo "    - $base"
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
    done
  done

  if [[ "$fail" -ne 0 ]]; then
    printf '\nSAMPLE INTEGRITY CHECK FAILED\n'
    exit 1
  fi

  printf 'SAMPLE INTEGRITY CHECK PASSED\n'
}
