#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="$ROOT/samples/pdf_layout_classifier/manifest.tsv"
OUT_DIR="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}/pdf_layout_classifier/features"

run_layout_tool() {
  local bin="$ROOT/_build/native/debug/build/tools/pdf_layout_classifier/pdf_layout_classifier.exe"
  if [[ -x "$bin" ]]; then
    "$bin" "$@"
  else
    moon run "$ROOT/tools/pdf_layout_classifier" -- "$@"
  fi
}

mkdir -p "$OUT_DIR"

tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r sample_id pdf_path label_source label_path notes; do
  [[ -n "$sample_id" ]] || continue
  record_kind="block"
  if [[ "$sample_id" == pdf_cross_page_should_merge_phase15 || "$sample_id" == pdf_cross_page_should_not_merge_phase15 ]]; then
    record_kind="boundary"
  elif [[ "$sample_id" == pdf_two_column_negative_phase15 ]]; then
    record_kind="all"
  fi

  run_layout_tool export \
    --sample-id "$sample_id" \
    --input "$ROOT/$pdf_path" \
    --record-kind "$record_kind" \
    --output "$OUT_DIR/$sample_id.features.tsv"
done

echo "exported features to $OUT_DIR"
