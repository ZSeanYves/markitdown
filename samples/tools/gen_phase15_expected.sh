#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PDF_DIR="$ROOT/samples/pdf"
EXP_DIR="$ROOT/samples/expected/pdf"
OUT_DIR="$ROOT/.tmp_phase15_pdf"

mkdir -p "$EXP_DIR" "$OUT_DIR"

cases=(
  pdf_two_column_negative_phase15
  pdf_header_footer_variants_phase15
  pdf_heading_false_positive_phase15
  pdf_cross_page_should_merge_phase15
  pdf_cross_page_should_not_merge_phase15
)

for name in "${cases[@]}"; do
  in="$PDF_DIR/$name.pdf"
  out="$OUT_DIR/$name.md"
  exp="$EXP_DIR/$name.md"

  if [[ ! -f "$in" ]]; then
    echo "[skip] missing sample: $in"
    continue
  fi

  moon run "$ROOT/src/cli" -- convert "$in" -o "$out" --max-heading 6
  cp "$out" "$exp"
  echo "[ok] updated expected: $exp"
done
