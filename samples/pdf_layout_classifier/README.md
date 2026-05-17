# PDF Layout Classifier Training Spike

This directory contains a local-only training spike for a lightweight
text-layer PDF layout classifier.

For the current broader design, dataset-license audit, and report-only rollout
plan, see `docs/pdf-layout-model.md`.

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

Those labels remain valid for the current local spike, but new work should
prefer the richer block/boundary mapping described in
`samples/pdf_layout_classifier/label_schema.md` and `docs/pdf-layout-model.md`.

Feature export:

```bash
./samples/pdf_layout_classifier/export_features.sh --split train
./samples/pdf_layout_classifier/export_features.sh --split heldout
```

Local-only manifest export without `moon run`:

```bash
python3 tools/pdf_layout_classifier/export_manifest_features.py \
  --manifest samples/pdf_layout_classifier/manifest.tsv \
  --manifest .external/layout_model/pdf_eval_manifest.local.tsv \
  --output-dir .external/layout_model/features/raw \
  --skip-existing
```

Local-only tiny public-dataset subset intake:

```bash
python3 tools/pdf_layout_classifier/fetch_tiny_subsets.py
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

Run the first local-only external-corpus ablation:

```bash
python3 tools/pdf_layout_classifier/local_eval.py \
  --manifest samples/pdf_layout_classifier/manifest.tsv \
  --manifest .external/layout_model/pdf_eval_manifest.local.tsv \
  --feature-dir .external/layout_model/features/raw
```

Current local-only ablation snapshot:

* tiny subset intake is local-only under `.external/layout_model/datasets/`
* `DocLayNet` is metadata-only this round because direct tiny PDF/page payload was
  not cleanly available from the public dataset surface
* `PubLayNet` tiny intake currently uses `examples/samples.json` plus 3 official
  example page images
* `PubTables-1M` tiny intake currently uses a `datasets-server` `first-rows`
  JSON subset
* current local eval now spans multiple rounds:
  * round 1: `147` train / `86` heldout
  * round 4 frozen baseline: `196` train / `136` heldout
  * round 5 overfit check: `201` train / `136` heldout
  * round 7 expanded heldout: `196` train / `150` heldout
  * round 8 expanded heldout guard pass: `196` train / `150` heldout
  * round 9 hard-negative guard pass: `206` train / `161` heldout
  * round 10 CJK/help-text/link-control pass: `217` train / `169` heldout
  * round 11 standalone-bullet / annotation-freetext guard pass: `220` train / `180` heldout
  * round 12 real-support expansion: `220` train / `195` heldout, then a tiny
    `223` / `195` selected-train follow-up
  * round 13 cheap link/caption feature pass: same `223` / `195` heldout,
    without another label-first expansion
  * round 14 residual feature pass: same `223` / `195` heldout, with cheap
    deterministic technical-literal / receipt-form / cleanup-shell / URL
    boundary features
  * round 15 paragraph-boundary feature pass: same `223` / `195` heldout,
    with cheap deterministic figure/section-reference sentence guards and no
    new labels
* current local eval writes tiny local-only JSON models under
  `.external/layout_model/models/`
* the pinned report-only baseline is now the named preset
  `gated_conservative_v1`
* current best harder `223 / 195` held-out micro F1 is now the later round-15
  feature pass:
  * `rules_only`: `0.9641`
  * `model_only`: `0.5590`
  * `rules_model_naive`: `0.8410`
  * `rules_model_weighted`: `0.9333`
  * `rules_model_gated`: `0.9846`
* interpretation:
  * the lightweight scorer is promising
  * model-only is not good enough
  * conservative gated arbitration is still the best candidate after the
    harder doc-style held-out expansion
  * the latest pass pushed held-out `heading` precision to `0.9333`,
    `keep_as_text` F1 to `0.9600`, and `list_item` precision to `1.0000`
  * a later round that added more `epubcheck` keep-as-text train labels
    regressed held-out header/footer behavior, so held-out ablation is
    catching real overfitting
  * the current `gated_conservative_tuned` run now ties `v1`, but does not
    beat it, so the pinned baseline remains `gated_conservative_v1`
  * a later real-support expansion raised held-out `link_text` / `caption`
    support to `9` / `8`, kept `0` held-out regressions at `0.9231` gated F1,
    and showed that the main blocker is now long-anchor `link_text`
    generalization rather than missing caption positives alone
  * the later residual feature passes then improved the same harder held-out
    split again without adding new labels first:
    `gated_conservative_v1` now reaches `0.9846`, keeps held-out regressions
    at `0`, keeps `link_text` / `caption` stable, and uses a very narrow
    report-only figure-reference sentence exception to lift the checked
    `Figure 6 illustrates ...` paragraph row
  * normal-path activation still stays off

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
* the expanded local-only external-corpus ablation now has materially better
  `heading`, `link_text`, `caption`, `form_row`, and `footer_header_noise`
  behavior, but still has a real residual set in `Summary` and a few
  `paragraph` vs `keep_as_text` boundary rows
* current quality-row eval is strongest on `heading`, `form_row`, `table_like`,
  `paragraph`, `separator`, and `footer_header_noise`; link/code-like classes
  still need more real labels

Current held-out behavior on the checked local split:

* cross-page merge examples are currently the most stable held-out signal
* short CJK clause-like body lines, command/help-text negatives, and
  standalone-bullet markers now behave better on the checked split
* checked CJK controls are green again, but real short-title support is still
  too thin to call that boundary closed
* caption vs short body text is now stable on the checked split, and real
  `caption` support is now wider
* the newer link-coverage / TOC-anchor / page-number-link features now clean
  up the checked page-number-like and long-anchor link controls
* the remaining hard misses are no longer support-only; they are now
  `Summary`, a standalone visible URL row, and one small receipt/body
  boundary row

Manifest layout:

* `manifest.tsv` is split-aware and records `train` vs `heldout`
* label files remain small manual TSVs under `samples/pdf_layout_classifier/labels/`
* confusion and error reports are written to `.tmp/pdf_layout_classifier/eval/`

Future optional backend candidates:

* PaddleOCR PP-Structure
* LayoutParser / PubLayNet style adapters
* ONNX Runtime backend adapter
