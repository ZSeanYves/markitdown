#!/usr/bin/env bash

lane_input_dir() {
  local fmt="$1"
  local lane="$2"
  printf '%s/%s/%s' "$SAMPLES_DIR" "$fmt" "$lane"
}

sample_lane_cli_args() {
  local fmt="$1"
  local lane="$2"
  local rel="$3"
  if [[ "$fmt" == "pdf" && "$lane" == "ocr" ]]; then
    printf '%s\n' "--ocr"
    return 0
  fi
  return 0
}

lane_expected_dir() {
  local fmt="$1"
  local lane="$2"
  printf '%s/%s/expected/%s' "$SAMPLES_DIR" "$fmt" "$lane"
}

discover_samples() {
  local fmt="$1"
  local lane="$2"
  local in_dir
  in_dir="$(lane_input_dir "$fmt" "$lane")"
  if [[ ! -d "$in_dir" ]]; then
    return 0
  fi
  case "$fmt" in
    docx) find "$in_dir" -type f -name "*.docx" -print ;;
    pdf) find "$in_dir" -type f -name "*.pdf" -print ;;
    xlsx) find "$in_dir" -type f -name "*.xlsx" -print ;;
    pptx) find "$in_dir" -type f -name "*.pptx" -print ;;
    html) find "$in_dir" -type f \( -name "*.html" -o -name "*.htm" \) -print ;;
    csv) find "$in_dir" -type f -name "*.csv" -print ;;
    tsv) find "$in_dir" -type f -name "*.tsv" -print ;;
    txt) find "$in_dir" -type f -name "*.txt" -print ;;
    xml) find "$in_dir" -type f -name "*.xml" -print ;;
    json) find "$in_dir" -type f -name "*.json" -print ;;
    jsonl) find "$in_dir" -type f -name "*.jsonl" -print ;;
    ndjson) find "$in_dir" -type f -name "*.ndjson" -print ;;
    yaml) find "$in_dir" -type f \( -name "*.yaml" -o -name "*.yml" \) -print ;;
    markdown) find "$in_dir" -type f \( -name "*.md" -o -name "*.markdown" \) -print ;;
    zip) find "$in_dir" -type f -name "*.zip" -print ;;
    epub) find "$in_dir" -type f -name "*.epub" -print ;;
    ocr) find "$in_dir" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.bmp" -o -name "*.webp" -o -name "*.tif" -o -name "*.tiff" \) -print ;;
    *) return 0 ;;
  esac
}

resolve_expected_fixture() {
  local fmt="$1"
  local lane="$2"
  local rel_no_ext="$3"
  case "$lane" in
    markdown)
      printf '%s/%s.md\n' "$(lane_expected_dir "$fmt" "$lane")" "$rel_no_ext"
      ;;
    ocr)
      printf '%s/%s.md\n' "$(lane_expected_dir "$fmt" "$lane")" "$rel_no_ext"
      ;;
    rag)
      printf '%s/%s.rag.json\n' "$(lane_expected_dir "$fmt" "$lane")" "$rel_no_ext"
      ;;
    assets)
      printf '%s/%s/result.md\n' "$(lane_expected_dir "$fmt" "$lane")" "$rel_no_ext"
      ;;
  esac
}
