#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_ROOT="$TMP_ROOT/pdf_layout_classifier"
FEATURE_DIR="$OUT_ROOT/features"
MODEL_PATH="$OUT_ROOT/models/pdf_layout_linear.json"
PRED_DIR="$OUT_ROOT/predictions"
EVAL_DIR="$OUT_ROOT/eval"
SUMMARY_PATH="$EVAL_DIR/summary.tsv"
SMOKE=0

run_layout_tool() {
  local bin="$ROOT/_build/native/debug/build/tools/pdf_layout_classifier/pdf_layout_classifier.exe"
  if [[ -x "$bin" ]]; then
    "$bin" "$@"
  else
    moon run "$ROOT/tools/pdf_layout_classifier" -- "$@"
  fi
}

if [[ "${1-}" == "--smoke" ]]; then
  SMOKE=1
fi

mkdir -p "$FEATURE_DIR" "$PRED_DIR" "$EVAL_DIR" "$(dirname "$MODEL_PATH")"

"$ROOT/samples/pdf_layout_classifier/export_features.sh"

python3 "$ROOT/tools/pdf_layout_classifier/train.py" \
  --manifest "$ROOT/samples/pdf_layout_classifier/manifest.tsv" \
  --feature-dir "$FEATURE_DIR" \
  --output "$MODEL_PATH"

tail -n +2 "$ROOT/samples/pdf_layout_classifier/manifest.tsv" | while IFS=$'\t' read -r sample_id pdf_path label_source label_path notes; do
  [[ -n "$sample_id" ]] || continue
  run_layout_tool infer \
    --model "$MODEL_PATH" \
    --features "$FEATURE_DIR/$sample_id.features.tsv" \
    --output "$PRED_DIR/$sample_id.predictions.tsv"
done

python3 "$ROOT/tools/pdf_layout_classifier/train.py" \
  --manifest "$ROOT/samples/pdf_layout_classifier/manifest.tsv" \
  --feature-dir "$FEATURE_DIR" \
  --pred-dir "$PRED_DIR" \
  --summary "$SUMMARY_PATH" \
  --evaluate-only

if [[ "$SMOKE" -eq 1 ]]; then
  head -n 20 "$SUMMARY_PATH"
else
  cat "$SUMMARY_PATH"
fi
