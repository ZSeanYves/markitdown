#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/.tmp_pdf_assets"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

FILES=(
  "pdf_image_single_page_single_image.pdf"
  "pdf_image_single_page_mixed.pdf"
  "pdf_image_multi_page.pdf"
)

for f in "${FILES[@]}"; do
  in="$ROOT/samples/pdf/$f"
  out="$OUT_DIR/${f%.pdf}.md"
  moon run "$ROOT/cli" -- normal "$in" "$out"

done

refs="$(rg -No "assets/[A-Za-z0-9_./-]+" "$OUT_DIR" -g '*.md' | cut -d: -f3 | sort -u)"
missing=0
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  if [[ ! -f "$OUT_DIR/$ref" ]]; then
    echo "missing asset: $OUT_DIR/$ref"
    missing=1
  fi
done <<< "$refs"

if [[ $missing -ne 0 ]]; then
  exit 1
fi

echo "pdf asset extraction check passed"
