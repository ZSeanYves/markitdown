#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="$ROOT/samples/pdf_layout_classifier/manifest.tsv"
OUT_DIR="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}/pdf_layout_classifier/features"
SPLIT_FILTER=""

run_layout_tool() {
  moon run "$ROOT/tools/pdf_layout_classifier" -- "$@"
}

if [[ "${1-}" == "--split" ]]; then
  SPLIT_FILTER="${2-}"
  if [[ -z "$SPLIT_FILTER" ]]; then
    echo "missing value for --split" >&2
    exit 1
  fi
elif [[ "${1-}" != "" ]]; then
  echo "usage: ./samples/pdf_layout_classifier/export_features.sh [--split train|heldout]" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r sample_id pdf_path record_kind split label_source label_path notes; do
  [[ -n "$sample_id" ]] || continue
  if [[ -n "$SPLIT_FILTER" && "$split" != "$SPLIT_FILTER" ]]; then
    continue
  fi

  run_layout_tool export \
    --sample-id "$sample_id" \
    --input "$ROOT/$pdf_path" \
    --record-kind "$record_kind" \
    --output "$OUT_DIR/$sample_id.features.tsv"
done

echo "exported features to $OUT_DIR"
