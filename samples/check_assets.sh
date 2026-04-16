#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/.tmp_assets_test"

extract_asset_refs() {
  local dir="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -o --no-filename "assets/[A-Za-z0-9_./-]+" "$dir" -g '*.md' | sort -u || true
    return
  fi

  find "$dir" -type f -name '*.md' -print0 \
    | xargs -0 grep -hoE "assets/[A-Za-z0-9_./-]+" \
    | sort -u || true
}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

run_group() {
  local format="$1"
  shift
  local files=("$@")

  echo "==> checking ${format} assets"

  local group_dir="$OUT_DIR/$format"
  mkdir -p "$group_dir"

  for f in "${files[@]}"; do
    local in="$ROOT/samples/image/$f"
    local stem="${f%.*}"
    local out="$group_dir"
    local expected_md="$group_dir/${stem}.md"

    moon run "$ROOT/cli" -- normal "$in" "$out"

    if [[ ! -f "$expected_md" ]]; then
      echo "missing markdown output for $format: $expected_md"
      return 1
    fi
  done

  local refs
  refs="$(extract_asset_refs "$group_dir")"

  if [[ -z "${refs//[$'\t\r\n ']}" ]]; then
    echo "no asset refs found in generated markdown for $format"
    return 1
  fi

  local missing=0
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$group_dir/$ref" ]]; then
      echo "missing asset for $format: $group_dir/$ref"
      missing=1
    fi
  done <<< "$refs"

  if [[ $missing -ne 0 ]]; then
    return 1
  fi

  echo "$format asset extraction check passed"
}

run_group pdf \
  "pdf_image_form_xobject.pdf" \
  "pdf_image_xobject.pdf" \
  "pdf_image_inline.pdf"

run_group pptx \
  "pptx_image_single.pptx" \
  "pptx_image_mixed.pptx" \
  "pptx_image_multi.pptx"

run_group html \
  "html_img_single.html" \
  "html_img_mixed.html" \
  "html_img_multi_subdir.html"

echo "all asset extraction checks passed"