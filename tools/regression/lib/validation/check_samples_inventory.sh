#!/usr/bin/env bash

manifest_inventory_rows() {
  if [[ ! -f "$MAIN_MANIFEST" ]]; then
    return 0
  fi
  awk -F '\t' '
    NR == 1 { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    { print }
  ' "$MAIN_MANIFEST"
}

manifest_formats() {
  manifest_inventory_rows | awk -F '\t' '{ print $2 }' | sort -u
}

manifest_count_rows() {
  local fmt="$1"
  local lane="$2"
  manifest_inventory_rows | awk -F '\t' -v fmt="$fmt" -v lane="$lane" '
    $2 == fmt && $3 == lane { count++ }
    END { print count + 0 }
  '
}

count_contract_fixtures() {
  local fmt="$1"
  local dir="$ROOT/samples/fixtures/contracts/$fmt"
  if [[ ! -d "$dir" ]]; then
    printf '0'
    return
  fi
  find "$dir" -maxdepth 1 -type f ! -name '.*' | wc -l | tr -d '[:space:]'
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
  printf 'format\tmain_markdown\tmain_rag\tmain_assets\tmain_ocr\tfixtures\tquality_records\n'
  while IFS= read -r fmt; do
    [[ -z "$fmt" ]] && continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$fmt" \
      "$(manifest_count_rows "$fmt" "markdown")" \
      "$(manifest_count_rows "$fmt" "rag")" \
      "$(manifest_count_rows "$fmt" "assets")" \
      "$(manifest_count_rows "$fmt" "ocr")" \
      "$(count_contract_fixtures "$fmt")" \
      "$(count_quality_comparison_reports "$fmt")"
  done < <(manifest_formats)
}

manifest_expected_exists() {
  local lane="$1"
  local expected_path="$2"
  case "$lane" in
    assets)
      [[ -d "$MAIN_CORPUS_ROOT/$expected_path" ]]
      ;;
    *)
      [[ -f "$MAIN_CORPUS_ROOT/$expected_path" ]]
      ;;
  esac
}

sample_integrity_is_noise_path() {
  local rel="$1"
  [[ "$rel" == .* ]] && return 0
  [[ "$rel" == *"/."* ]] && return 0
  [[ "$rel" == *~ ]] && return 0
  [[ "$rel" == *.swp ]] && return 0
  [[ "$rel" == *.tmp ]] && return 0
  return 1
}

check_sample_inventory_integrity() {
  local fail=0
  local seen_ids=""
  local line_no=1
  local row
  if [[ ! -f "$MAIN_MANIFEST" ]]; then
    echo "missing manifest: $MAIN_MANIFEST" >&2
    exit 1
  fi

  echo "==> sample integrity check"

  while IFS= read -r row; do
    line_no=$((line_no + 1))
    [[ -z "$row" ]] && continue
    [[ "$row" =~ ^[[:space:]]*# ]] && continue
    IFS=$'\t' read -r id fmt lane input_path expected_path _notes <<< "$row"
    if [[ -z "$id" || -z "$fmt" || -z "$lane" || -z "$input_path" || -z "$expected_path" ]]; then
      echo "[error] malformed manifest row at line $line_no" >&2
      fail=1
      continue
    fi
    if sample_integrity_is_noise_path "$input_path"; then
      echo "[error] noisy input path enrolled at line $line_no: $input_path" >&2
      fail=1
    fi
    case "$lane" in
      markdown|rag|assets|ocr)
        ;;
      *)
        echo "[error] unsupported lane at line $line_no: $lane" >&2
        fail=1
        ;;
    esac
    if [[ "$seen_ids" == *$'\n'"$id"$'\n'* ]]; then
      echo "[error] duplicate manifest id: $id" >&2
      fail=1
    else
      seen_ids+=$'\n'"$id"$'\n'
    fi
    if [[ ! -f "$MAIN_CORPUS_ROOT/$input_path" ]]; then
      echo "[error] manifest input missing: $input_path" >&2
      fail=1
    fi
    if ! manifest_expected_exists "$lane" "$expected_path"; then
      echo "[error] manifest expected missing: $expected_path" >&2
      fail=1
    fi
  done < <(manifest_inventory_rows)

  if [[ "$fail" -ne 0 ]]; then
    printf '\nSAMPLE INTEGRITY CHECK FAILED\n'
    exit 1
  fi

  printf 'SAMPLE INTEGRITY CHECK PASSED\n'
}
