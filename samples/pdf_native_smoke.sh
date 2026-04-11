#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/.tmp_pdf_native_smoke"
mkdir -p "$OUT_DIR"

# Minimal representative set for native extraction health:
# 1) single-page success
# 2) multi-page success
# 3) xref stream
# 4) objstm
# 5) simple font fallback
# 6) known edge sample (currently difficult)
SAMPLES=(
  "text_simple"
  "text_multipage"
  "pdf_heading_false_positive_phase15"
  "pdf_cross_page_paragraph"
  "hardwrap_zh"
  "pdf_two_column_negative_phase15"
)

for name in "${SAMPLES[@]}"; do
  in="$ROOT/samples/pdf/$name.pdf"
  out="$OUT_DIR/$name.md"
  log="$OUT_DIR/$name.log"

  if [[ ! -f "$in" ]]; then
    echo "[skip] missing sample: $in"
    continue
  fi

  echo "==> smoke: $name"
  moon run "$ROOT/cli" -- convert "$in" -o "$out" --debug extract >"$log" 2>&1

  if ! grep -q "native_stats" "$log"; then
    echo "[error] missing native_stats debug line for $name"
    cat "$log"
    exit 1
  fi

  if grep -q "fatal=true" "$log"; then
    echo "[error] fatal native extraction detected for $name"
    cat "$log"
    exit 1
  fi

  echo "[ok] $name"
  tail -n 2 "$log"
done

echo "PDF native smoke passed"
