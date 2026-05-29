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
* paragraph soft merge for nearby same-flow fragments
* numbered heading split/promotion when the extracted text signal is strong
* superscript-style marker attachment through shared note refs
* high-confidence URI annotation links when the visible label is unique and
  aligned with extracted text
* two-column guards that prevent nearby fragments from being merged across
  separate x-bands

## Native Text-Flow And Annotation Links

Current native text-flow cleanup is conservative and evidence-led. It is meant
to recover common text-PDF reading structure without turning the converter into
a visual reconstruction engine.

Current shipped behavior includes:

* page-local paragraph soft merge when geometry and text signals indicate the
  fragments belong to the same paragraph
* cross-page paragraph continuation on narrow, high-confidence cases
* numbered heading split/promotion for patterns such as `1. Heading` when the
  heading signal is strong enough
* superscript-style marker attachment that lowers into shared `NoteRef`
  semantics while still using PDF marker-only fallback
* same-column / x-overlap guards so two-column nearby lines do not merge into
  one paragraph

Current annotation-link behavior:

* URI link annotations can emit Markdown links when the annotation is matched
  to visible extracted text with high confidence
* if a matched URI label is a unique substring inside a merged text block, only
  that visible label is upgraded to `[label](url)`
* duplicate visible labels, invisible-only annotation internals, and ambiguous
  matches stay plain text
* popup/text annotations are emitted only through the existing annotation
  appendix policy; they are not dumped into body text or attached to unrelated
  content

Still out of scope:

* PDF footnote body association
* broad page-bottom note harvesting
* OCR or page-raster inference
* runtime model/gate loading

## OCR Boundary

Current OCR/Vision boundary:

* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  supported
* image inputs now auto-OCR through `convert/vision`
* product image OCR depends on local `tesseract` and language data
* image OCR uses the MoonBit-owned `convert/vision` path, including
  provider-independent `OCRPageModel`
* the normal path does not auto-probe OCR providers
* scanned PDFs are not silently upgraded into OCR-driven normal output
* scanned/image-only PDFs stay fail-closed in the normal path
* PDF OCR is not wired in this build
* image inputs are handled on the main CLI OCR path rather than the PDF path
* PDF `--ocr` also fails closed in the current release
* future PDF OCR must stay on an explicit provider path
* a future PDF OCR route requires an explicit provider audit, such as an
  OCRmyPDF-style path, rather than a normal-path fallback
* current release still keeps PDF OCR entirely out of the product path
* current image OCR implementation does not change the native PDF text path

## Scan-Only Diagnostics

Current scan-only / low-text PDF diagnostics are report-only.

They exist to help maintainers answer:

* does this PDF expose native embedded text?
* is the current extraction signal low enough that a future explicit OCR path
  might help?
* is this file image-heavy without changing current product behavior?

Current explicit entrypoints:

* `moon build debug --target native`
* `./_build/native/debug/build/debug/debug.exe --json <input.pdf>`
* `bash samples/helpers/contracts/check_pdf_scan_diagnostics.sh`
* `bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh`

Current report fields come from the existing PDF inspect/debug surface and
include:

* `page_count`
* `text_signal_level`
* `native_text_char_count`
* `page_image_count`
* `has_embedded_text`
* `has_page_images`
* `image_only`
* `ocr_recommended`
* `ocr_mode`
* `ocr_used`

Current interpretation rules:

* these signals are diagnostic only
* they do not trigger OCR
* they do not probe providers
* they do not change normal PDF Markdown output
* they do not turn the shipped runtime into scanned-PDF support
* `ocr_recommended` means future explicit OCR may be worth evaluating, not
  that OCR was attempted

Current summary helper contract:

* `bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh` emits a
  stable TSV summary for a tiny repo-local PDF sample set
* it requires a prebuilt debug binary from
  `moon build debug --target native`
* it also supports an explicit override such as
  `MARKITDOWN_DEBUG=_build/native/debug/build/debug/debug.exe bash samples/helpers/validation/summarize_pdf_scan_diagnostics.sh`
* it reads existing `debug --json` output and does not change that schema
* it is an optional report/debug aid, not a release hard gate

## Future PDF OCR Provider Design

This section is design-only. It documents the intended boundary for a future
explicit PDF OCR path and does not mean that PDF OCR is shipped now.

### A. Current Behavior

Current facts:

* the default PDF path stays on native text/assets/metadata extraction
* forcing `--ocr` on PDF currently fails closed
* scanned/image-only PDFs are not automatically OCRed
* report-only scan diagnostics may recommend OCR, but they do not execute OCR
* shipped image OCR support does not imply scanned-PDF or PDF OCR support

### B. Product Semantics For Future PDF OCR

Future product intent:

* PDF OCR must remain explicit opt-in
* there must be no automatic fallback from the native PDF path to OCR
* the normal PDF path must not probe OCR providers
* `--ocr` may become the explicit user signal for PDF OCR in a later phase,
  but that behavior is not wired now
* when provider runtime support or language data is unavailable, the explicit
  PDF OCR path should fail closed rather than silently degrading into native
  PDF output or partial OCR output

### C. Provider Boundary

Possible future provider families include:

* an OCRmyPDF-style PDF-level provider
* page-image extraction plus image OCR routed back through the shared
  `convert/vision` bridge
* heavier optional audited providers such as PaddleOCR or Surya on explicit
  non-default paths

Current non-commitments:

* none of those providers are wired now
* no provider is selected automatically now
* no OCR model, runtime, or tessdata is downloaded by the current product path
* current native PDF conversion remains provider-free

### D. Output Boundary

Future PDF OCR output should respect the existing shared-output boundary:

* OCR-derived PDF output should only enter the shared IR/Markdown path after
  explicit OCR has been selected
* native PDF output must remain unchanged unless an explicit OCR path is
  chosen
* current semantic hints such as `TableLike`, `KeyValueLike`, and
  `CaptionLike` remain advisory side-channel signals only
* those hints do not guarantee Markdown table, key-value, or caption
  reconstruction for future PDF OCR output

### E. Diagnostics Relationship

Current and future diagnostics rules:

* current PDF scan diagnostics remain report-only
* `ocr_recommended=true` means a user may try an explicit OCR path when one is
  available; it does not mean OCR was used
* current native/debug diagnostics must continue to keep `ocr_used=false`
* current report-only native/debug summaries should continue to show
  `ocr_mode=native` until an explicit PDF OCR path exists
* report-only diagnostics and future PDF OCR execution must stay separate
  validation layers

## Quality-Lab Relation

The repo-root quality-lab carries the offline PDF layout lab:

```text
markitdown-quality-lab/pdf_model_training
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
* `convert/vision`: OCRPageModel scaffold for future provider signal and layout
  recovery
* `doc_parse/pdf/layout_model_tool`: MoonBit dev export/infer entrypoint

Important boundary:

* `doc_parse/pdf/layout_model_tool` is a dev/export/infer tool
* it is not part of product runtime
* `convert/pdf` owns native PDF text/assets/metadata extraction only
* `convert/pdf` does not own OCR providers
* `convert/vision` remains the only OCR/Vision implementation path

## PDF Note Marker Boundary

Current PDF footnote/endnote behavior is intentionally narrow:

* superscript-like inline markers can be recognized on the native text path
* recognized markers now lower into shared IR `NoteRef` semantics instead of a
  PDF-private raw-string patch
* current PDF Markdown output uses marker-only fallback such as `^3` when the
  body association is not reliable
* current PDF conversion avoids dangling full Markdown footnotes like `[^3]`
  because no reliable PDF note body association is shipped yet
* full Markdown footnotes are emitted only when a resolved note body exists in
  shared IR
* structured formats such as DOCX, Markdown, and explicit HTML/EPUB noterefs can
  emit full Markdown footnotes through shared `NoteRef` and `NoteDefinition`

Current non-goals for the shipped PDF path:

* no full PDF footnote-body association yet
* no broad page-bottom note harvesting heuristic
* no visual guess that turns every superscript into a body-backed footnote
* no PDF-private note syntax that bypasses shared IR

Future intended direction:

* keep note semantics in shared IR
* prefer full note-definition recovery first in formats with strong structure
  such as DOCX/HTML/EPUB/Markdown
* add PDF body association only after it is reliable enough to avoid dangling
  footnotes

## Guardrails

Normal-path PDF/layout work must keep these guardrails:

* deterministic table/caption/link/page-reference facts win over layout scoring
* normal PDF conversion remains no-OCR
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
* repo-local sample validation: `bash samples/check.sh` passes 9 stages,
  including `444` markdown / `85` metadata / `90` assets / `0` failures
* `bash samples/check_quality.sh`: external-corpus-only gate; row counts depend
  on the checked-out `markitdown-quality-lab` contents
* `bash samples/check_quality.sh --format pdf`: `79` rows / `0` failed / `1`
  skipped / `0` expected_fail on the current repo-local quality-lab checkout

Interpretation:

* runtime and repo-local validation stay self-contained in the main repo
* optional full quality and offline layout work do use quality-lab
