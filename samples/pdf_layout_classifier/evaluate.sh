#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
OUT_ROOT="$TMP_ROOT/pdf_layout_classifier"
FEATURE_DIR="$OUT_ROOT/features"
MODEL_PATH="$OUT_ROOT/models/pdf_layout_linear.json"
PRED_DIR="$OUT_ROOT/predictions"
EVAL_DIR="$OUT_ROOT/eval"
SMOKE=0
RUN_HELDOUT=0

run_layout_tool() {
  moon run "$ROOT/tools/pdf_layout_classifier" -- "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --smoke)
      SMOKE=1
      ;;
    --heldout)
      RUN_HELDOUT=1
      ;;
    *)
      echo "usage: ./samples/pdf_layout_classifier/evaluate.sh [--smoke] [--heldout]" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$SMOKE" -eq 1 ]]; then
  RUN_HELDOUT=1
fi

mkdir -p "$FEATURE_DIR" "$PRED_DIR" "$EVAL_DIR" "$(dirname "$MODEL_PATH")"

"$ROOT/samples/pdf_layout_classifier/export_features.sh" --split train
if [[ "$RUN_HELDOUT" -eq 1 ]]; then
  "$ROOT/samples/pdf_layout_classifier/export_features.sh" --split heldout
fi

python3 "$ROOT/tools/pdf_layout_classifier/train.py" \
  --manifest "$ROOT/samples/pdf_layout_classifier/manifest.tsv" \
  --train-features "$FEATURE_DIR" \
  --output "$MODEL_PATH" \
  --train-summary "$EVAL_DIR/train_summary.tsv"

if [[ "$RUN_HELDOUT" -eq 1 ]]; then
  tail -n +2 "$ROOT/samples/pdf_layout_classifier/manifest.tsv" | while IFS=$'\t' read -r sample_id pdf_path record_kind split label_source label_path notes; do
    [[ -n "$sample_id" ]] || continue
    if [[ "$split" != "heldout" ]]; then
      continue
    fi
    run_layout_tool infer \
      --model "$MODEL_PATH" \
      --features "$FEATURE_DIR/$sample_id.features.tsv" \
      --output "$PRED_DIR/$sample_id.predictions.tsv"
  done
fi

if [[ "$RUN_HELDOUT" -eq 1 ]]; then
  python3 "$ROOT/tools/pdf_layout_classifier/train.py" \
    --manifest "$ROOT/samples/pdf_layout_classifier/manifest.tsv" \
    --train-features "$FEATURE_DIR" \
    --heldout-features "$FEATURE_DIR" \
    --pred-dir "$PRED_DIR" \
    --train-summary "$EVAL_DIR/train_summary.tsv" \
    --heldout-summary "$EVAL_DIR/heldout_summary.tsv" \
    --confusion "$EVAL_DIR/confusion.tsv" \
    --errors "$EVAL_DIR/errors.tsv" \
    --evaluate-only
fi

if [[ "$SMOKE" -eq 1 ]]; then
  head -n 20 "$EVAL_DIR/train_summary.tsv"
  echo
  head -n 20 "$EVAL_DIR/heldout_summary.tsv"
else
  cat "$EVAL_DIR/train_summary.tsv"
  if [[ "$RUN_HELDOUT" -eq 1 ]]; then
    echo
    cat "$EVAL_DIR/heldout_summary.tsv"
    echo
    echo "confusion: $EVAL_DIR/confusion.tsv"
    echo "errors: $EVAL_DIR/errors.tsv"
  fi
fi
