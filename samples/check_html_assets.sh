#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/.tmp_assets_test"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

FILES=(
  "html_img_single.html"
  "html_img_mixed.html"
  "html_img_multi_subdir.html"
)

for f in "${FILES[@]}"; do
  in="$ROOT/samples/html/$f"
  out="$OUT_DIR/${f%.html}.md"
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

echo "html asset extraction check passed"
