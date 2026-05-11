# PDF Layout Classifier Training Spike

This directory contains a local-only training spike for a lightweight
text-layer PDF layout classifier.

Purpose:

* export layout features from existing checked-in PDF samples
* keep a small local manual label corpus
* train a lightweight local model
* validate MoonBit JSON loading and deterministic inference
* compare train and held-out results without changing default PDF output

Current scope:

* text-layer features only
* no OCR
* no visual layout detector
* no ONNX Runtime
* no PaddleOCR
* no LayoutParser runtime integration
* no change to default PDF conversion output

Label schema:

* `BodyText`
* `Heading`
* `Noise`
* `PageNumber`
* `HeaderFooter`
* `Caption`
* `TableLike`
* `CrossPageMerge`
* `CrossPageNoMerge`
* `ColumnBoundary`
* `Unknown`

Feature export:

```bash
./samples/pdf_layout_classifier/export_features.sh --split train
./samples/pdf_layout_classifier/export_features.sh --split heldout
```

Train:

```bash
python3 tools/pdf_layout_classifier/train.py \
  --manifest samples/pdf_layout_classifier/manifest.tsv \
  --train-features .tmp/pdf_layout_classifier/features \
  --output .tmp/pdf_layout_classifier/models/pdf_layout_linear.json
```

Evaluate:

```bash
./samples/pdf_layout_classifier/evaluate.sh --heldout
```

Current limitations:

* this is still a training spike on a small local corpus
* current held-out numbers are only small-sample checks, not generalized quality claims
* the currently best-covered labels are `Heading`, `BodyText`, `Caption`, `TableLike`,
  `CrossPageMerge`, `CrossPageNoMerge`, and `Unknown`
* `Noise`, `PageNumber`, `HeaderFooter`, and `ColumnBoundary` remain export-ready but do
  not yet have enough reliable labels in the current local corpus
* the current model is a lightweight text-layer classifier, not an OCR system
* the current model is not connected to the default PDF main path
* code license, dataset license, and model-weight license are different
  concerns; do not vendor third-party model weights by default

Current held-out behavior on the checked local split:

* cross-page merge examples are currently the most stable held-out signal
* short body lines, bullet items, and image-adjacent prose still confuse the lightweight model
* caption vs short body text and heading vs short sentence remain the main error clusters

Manifest layout:

* `manifest.tsv` is split-aware and records `train` vs `heldout`
* label files remain small manual TSVs under `samples/pdf_layout_classifier/labels/`
* confusion and error reports are written to `.tmp/pdf_layout_classifier/eval/`

Future optional backend candidates:

* PaddleOCR PP-Structure
* LayoutParser / PubLayNet style adapters
* ONNX Runtime backend adapter
