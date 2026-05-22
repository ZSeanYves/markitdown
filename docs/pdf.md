# PDF

This page explains the current PDF text/layout/OCR boundary in
`markitdown-mb`.

It focuses on the shipped design:

* normal PDF conversion is rule-driven
* the normal path does not load Python, JSON weights, or external model files
* offline training/evaluation lives in the repo-root quality-lab
* any normal-path layout changes must be distilled into narrow MoonBit rules

## Current Runtime Shape

Current normal-path PDF behavior is a narrow MoonBit gate layered on top of the
native text-PDF pipeline.

Important facts:

* no runtime model JSON dependency
* no runtime quality-lab dependency
* no OCR/page-raster model in the normal path
* no provider-backed runtime classifier
* native PDF conversion stays limited to text, assets, and metadata extraction

Current enabled normal-path scope stays intentionally small:

* weak heading demotion
* separator / false-bullet suppression
* a narrow receipt settlement-line demotion

## OCR Boundary

Current OCR/Vision boundary:

* OCR product execution is not wired in this build
* OCR is being rebuilt around provider-independent `OCRPageModel` under
  `convert/vision`
* the normal path does not auto-probe OCR providers
* scanned PDFs are not silently upgraded into OCR-driven normal output
* scanned/image-only PDFs stay fail-closed in the normal path
* PDF OCR is not wired in this build
* previous text-only OCR prototype has been retired
* future PDF OCR must stay on an explicit provider path
* a future PDF OCR route requires an explicit provider audit, such as an
  OCRmyPDF-style path, rather than a normal-path fallback
* current Vision/OCR work is internal/dev scaffold, not a product PDF OCR path
* current OCR/Vision scaffold does not change the native PDF text path

## Quality-Lab Relation

The repo-root quality-lab carries the offline PDF layout lab:

```text
markitdown-quality-lab/pdf_layout_classifier
```

That lab is the home for:

* training/eval scripts
* local datasets and labels
* reports and held-out notes
* local model artifacts

The main repo keeps only:

* runtime code
* repo-tracked test fixtures required by `moon test`
* the MoonBit export/infer dev entrypoint

## Main-Repo Entry Points

Current main-repo PDF-related entrypoints:

* `convert/pdf`: normal PDF conversion logic
* `convert/pdf_layout`: feature and gate logic used by report/debug/dev surfaces
* `convert/pdf_debug`: explainability/debug-oriented PDF surface
* `ocr`: explicit OCR rebuild stub
* `convert/vision`: OCRPageModel scaffold for future provider signal and layout
  recovery
* `doc_parse/pdf/layout_model_tool`: MoonBit dev export/infer entrypoint

Important boundary:

* `doc_parse/pdf/layout_model_tool` is a dev/export/infer tool
* it is not part of product runtime
* `convert/pdf` owns native PDF text/assets/metadata extraction only
* `convert/pdf` does not own OCR providers

## Guardrails

Normal-path PDF/layout work must keep these guardrails:

* deterministic table/caption/link/page-reference facts win over layout scoring
* OCR remains explicit-only
* quality-lab remains offline training/eval infrastructure
* runtime behavior stays explainable and bounded
* any future scan-only PDF detection should start as report-only diagnostics
  before any OCR execution path is considered

Still out of scope for the normal path:

* generic receipt/body demotion from offline models
* numbered heading promotion from model output
* broad table/link/caption rewrite from model output
* provider-backed runtime model loading
* automatic PDF OCR fallback or provider probing

## Current Checked Boundary

Current checked facts:

* `moon test`: `1579 passed`
* public-only quality: `24 / 0 / 0`
* full quality with quality-lab: `330 / 1 / 0`
* focused PDF quality with quality-lab: `101 / 1 / 0`

Interpretation:

* runtime and public-only validation stay self-contained in the main repo
* optional full quality and offline layout work do use quality-lab
