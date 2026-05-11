# PDF Layout Classifier Training Spike

This directory contains a local-only training spike for a lightweight
text-layer PDF layout classifier.

Purpose:

* export layout features from existing checked-in PDF samples
* keep a tiny manual label corpus
* train a lightweight local model
* validate MoonBit JSON loading and deterministic inference

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
./samples/pdf_layout_classifier/export_features.sh
```

Train:

```bash
python3 tools/pdf_layout_classifier/train.py \
  --manifest samples/pdf_layout_classifier/manifest.tsv \
  --output .tmp/pdf_layout_classifier/models/pdf_layout_linear.json
```

Evaluate:

```bash
./samples/pdf_layout_classifier/evaluate.sh
```

Current limitations:

* training data is small and local-only
* several labels are placeholder-quality only
* the current model is a lightweight text-layer classifier, not an OCR system
* the current model is not connected to the default PDF main path
* code license, dataset license, and model-weight license are different
  concerns; do not vendor third-party model weights by default

Future optional backend candidates:

* PaddleOCR PP-Structure
* LayoutParser / PubLayNet style adapters
* ONNX Runtime backend adapter
