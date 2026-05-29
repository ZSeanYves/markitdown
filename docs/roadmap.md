# Roadmap

This page tracks the current forward-looking direction for the repository.

## Current Baseline

Current checked baseline:

* `moon test`: `1579 passed`
* `bash samples/check.sh`: 9 stages passed, including `444` markdown / `85`
  metadata / `90` assets / `0` failures
* `bash samples/check_quality.sh --format pdf`: `79` rows / `0` failed / `1`
  skipped / `0` expected_fail on the current repo-local quality-lab checkout
* `bash samples/check_quality.sh`: `315` rows / `0` failed / `1` skipped /
  `0` expected_fail on the current repo-local quality-lab checkout

Current structural baseline:

* runtime/test/repo-local validation flow is self-contained in the main repo
* repo-root `markitdown-quality-lab/` carries external corpus, full quality
  rows, and offline training/eval assets
* normal PDF layout behavior is distilled into MoonBit rules/gates
* shared note IR covers PDF marker-only refs, DOCX and Markdown structured
  notes, EPUB explicit noteref bodies, and explicit HTML noteref/body pairs
* no runtime model JSON dependency exists today

Recently completed:

* PDF text-flow hardening for paragraph soft merge, superscript marker
  attachment, numbered heading split/promotion, and two-column negative guards
* PDF annotation-link quality closure for high-confidence visible URI labels
  inside merged text blocks
* DOCX note sidecar snapshot alignment after notes moved from body paragraphs
  to document-level note definitions
* unified note IR support for DOCX, Markdown, EPUB strong noteref, and PDF
  marker-only fallback
* external quality corpus refresh for Python-Markdown footnote fixtures,
  official IRS/NIOSH PDF samples, and DOCX note-definition signal alignment

## Near-Term Direction

Current priorities:

* keep docs aligned with the current release-state workflow
* keep release dry-run helpers explicit about required vs optional diagnostics
* keep PDF layout work narrow, explicit, and evidence-led
* continue failure-driven hardening across Office and horizontal formats
* keep performance claims sample-scoped and reproducible
* keep normal document conversion no-OCR outside the explicit image OCR path
* keep image OCR explicit about its local `tesseract` runtime dependency
* rebuild product OCR around provider signal -> `OCRPageModel` -> MoonBit
  layout recovery -> unified IR -> Markdown

Completed OCR/Vision groundwork:

* provider-independent `OCRPageModel` / `OcrDocumentModel`
* tesseract TSV parser and internal/dev tooling, including
  `convert/vision/tsv_preview_tool`
* optional word-level line resegmentation from OCR word geometry
* OCR layout recovery into `OCRLayoutPage` / `OCRLayoutBlock`
* OCR layout -> shared document IR adapter through the current core document
  path
* OCR/Vision semantic hint side-channel for recovered block meaning
* current `TableLike`, `KeyValueLike`, and `CaptionLike` hint coverage
* quality-lab default preview, resegmented preview, and IR hint artifact checks
* read-only OCR quality-lab summary helper
* main-CLI image OCR landing while keeping normal-path no-OCR contracts intact
* Phase 2a main-CLI OCR policy parser/decision layer:
  `--ocr`, `--no-ocr`, image auto-OCR recognition, and fail-closed behavior
  without OCR execution
* Phase 2b main-CLI image OCR execution wiring through `convert/vision`
  with local `tesseract` dependency and fail-clear runtime errors
* Phase 2c minimal image-OCR language option:
  `--ocr-lang <LANG>` for Tesseract language selection on image inputs only

## Image OCR MVP Status

Completed:

* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  shipped
* image inputs now auto-OCR on the main CLI
* image `--ocr` and image `--no-ocr` are wired with fail-closed behavior
* image `--ocr-lang <LANG>` passes a Tesseract language value to image OCR
  only
* the shipped OCR execution path is the MoonBit-owned
  `convert/vision` pipeline:
  `tesseract TSV -> OCRPageModel -> line resegmentation -> layout recovery ->
  shared IR -> Markdown`
* the image OCR product contract is covered by
  `bash samples/helpers/contracts/check_ocr_contract.sh`
* the image OCR attribution smoke exists as a separate optional helper:
  `bash samples/helpers/bench/check_image_ocr_attribution_smoke.sh`

Still future:

* explicit PDF OCR provider wiring
* OCR provider selection beyond the current fixed local `tesseract` image path
* conservative HTML footnote inference beyond explicit noteref/body semantics
* PDF footnote body association after reliable body matching exists
* richer HTML/EPUB footnote body blocks when nested structure matters
* `--psm` / `--oem` product options if they are ever proven necessary
* real-world OCR corpus expansion beyond tiny main-repo fixtures
* Markdown reconstruction for OCR-derived tables, key-value layouts, and
  captions
* deeper OCR performance attribution beyond the current directional smoke

Release-stage meaning:

* image OCR is now a shipped product path for common image formats
* normal document conversion still stays no-OCR outside explicit image inputs
* PDF OCR is still out of scope for the shipped path
* image OCR remains dependent on local `tesseract` plus installed tessdata
* optional quality-lab OCR artifacts and OCR timing helpers remain optional
  diagnostics, not public-gate requirements

Next OCR/Vision steps:

* real license-clean OCR corpus audit
* hint artifact drift summaries or dashboards for OCR semantic changes
* extend PDF scan-only report-only diagnostics beyond the current debug/helper baseline when more explicit sample coverage is needed
* eventual table reconstruction beyond `TableLike` hints
* PDF OCR provider audit
* OCR provider options beyond `--ocr-lang`
* OCR performance deeper attribution when more phase-level evidence is needed
* future heavier OCR/layout provider audit only on explicit paths

Completed PDF diagnostic groundwork:

* report-only PDF inspect/debug signal for `text_signal_level`
* report-only PDF inspect/debug signal for `image_only`
* report-only PDF inspect/debug signal for `ocr_recommended`
* explicit contract/helper coverage for low-text vs normal-text PDF scan diagnostics

## Future Milestone: PDF OCR Explicit Provider Path

This milestone is future-only. It does not describe current shipped behavior.

Planned design tracks:

* provider policy for explicit, local, audited PDF OCR providers
* explicit CLI behavior for PDF OCR without changing the native default PDF
  path
* PDF OCR corpus and quality-lab sample policy for future explicit-provider
  evaluation
* PDF OCR performance attribution kept separate from native PDF and current
  image OCR timing
* fail-closed PDF OCR contracts for missing provider runtime support or
  missing language data

Still not current:

* normal path OCR beyond explicit image inputs
* PDF OCR
* image OCR without local `tesseract`
* Markdown table, key-value, or caption reconstruction

## Legacy Fallback Exit Criteria

Legacy fallback removal should wait until all of the following stay true on the
same cycle:

1. repo-root quality-lab full quality still passes on the current checked-out
   corpus
2. external quality still passes on the current checked-out
   `markitdown-quality-lab` corpus
3. `moon test` and `bash samples/check.sh` still pass
4. no non-doc runtime/product path depends on `.external/...`
5. no active workflow still depends on `external_manifest.local.tsv`
6. quality-lab tracked workflows are fully anchored on
   `external_quality/` and `pdf_model_training/`
7. at least one full post-migration cycle has completed

## Legacy Fallback Removal Plan

Current staged removal plan:

* Phase 1: remove legacy examples from user-facing docs while keeping lifecycle notes
* Phase 2: remove sibling `../markitdown-quality-lab` lookup
* Phase 3: remove legacy `samples/quality_corpus/external_manifest.local.tsv` runner fallback
* Phase 4: remove legacy `.external/quality_corpus/...` resolution from runner/helpers
* Phase 5: remove legacy `.external/layout_model/...` debug/layout-assist mapping

## Long-Term Direction

Long-term direction remains:

* main repo for runtime, tests, samples, and public baseline
* quality-lab for external corpus, full quality rows, and offline training/eval/model/report assets
* narrow, explicit, evidence-backed normal-path changes only
* future OCR expansion only through `convert/vision`, image-input main-CLI
  wiring, explicit `--ocr` / `--no-ocr` controls, and a later PDF OCR
  provider path, with OCRmyPDF/heavy providers kept opt-in
* main-repo OCR fixtures should stay tiny and license-clean; real-world OCR rows should live in quality-lab
* optional tesseract smoke should stay outside the default native quality gate
* OCR/Vision quality-lab artifact checks remain internal/dev diagnostics and do
  not imply scanned-PDF OCR support or broader OCR quality guarantees
* current OCR/Vision semantic hints are limited to vision-side side-channel
  tracking; they do not imply Markdown table, key-value, or caption
  reconstruction in the shipped build
* current conservative two-column reading order only helps after the provider
  signal already exposes separate line candidates; some natural two-column
  pages still need future word-level line resegmentation before layout
  recovery can reorder them
* future OCR follow-ups should stay explicit and auditable:
  `OCRPageModel`, TSV/HOCR signal providers, MoonBit layout recovery,
  OCR-to-IR lowering, OCRmyPDF provider audit, heavy OCR/layout provider audit,
  and preprocessing such as deskew/denoise only on explicit paths
