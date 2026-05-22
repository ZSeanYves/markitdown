# Roadmap

This page tracks the current forward-looking direction for the repository.

## Current Baseline

Current checked baseline:

* `moon test`: `1579 passed`
* `bash samples/check.sh`: `444` markdown / `85` metadata / `90` assets / `0`
  failures
* public-only quality: `24 / 0 / 0`
* full quality with quality-lab: `330 / 1 / 0`
* focused PDF quality with quality-lab: `101 / 1 / 0`

Current structural baseline:

* runtime/test/public-only flow is self-contained in the main repo
* repo-root `markitdown-quality-lab/` carries external corpus, full quality
  rows, and offline training/eval assets
* normal PDF layout behavior is distilled into MoonBit rules/gates
* no runtime model JSON dependency exists today

## Near-Term Direction

Current priorities:

* keep docs aligned with the current release-state workflow
* keep PDF layout work narrow, explicit, and evidence-led
* continue failure-driven hardening across Office and horizontal formats
* keep performance claims sample-scoped and reproducible
* keep OCR explicit-only and fail closed until an explicit product decision
  exists
* rebuild OCR around provider signal -> `OCRPageModel` -> MoonBit layout
  recovery -> unified IR -> Markdown

Completed internal Vision/OCR groundwork:

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

Next OCR/Vision steps:

* real license-clean OCR corpus audit
* hint artifact drift summaries or dashboards for OCR semantic changes
* product-path attribution benchmark
* PDF scan-only report-only diagnostics
* eventual table reconstruction beyond `TableLike` hints
* eventual product OCR decision and any future product CLI shape
* PDF OCR provider audit
* future heavier OCR/layout provider audit only on explicit paths

Still not current:

* product OCR CLI
* normal path OCR
* PDF OCR
* Markdown table, key-value, or caption reconstruction

## Legacy Fallback Exit Criteria

Legacy fallback removal should wait until all of the following stay true on the
same cycle:

1. repo-root quality-lab full quality still passes `330 / 1 / 0`
2. public-only still passes `24 / 0 / 0`
3. `moon test` and `bash samples/check.sh` still pass
4. no non-doc runtime/product path depends on `.external/...`
5. no active workflow still depends on `external_manifest.local.tsv`
6. quality-lab still tracks `quality_rows/manifest.tsv` and `corpus/MANIFEST.tsv`
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
* future OCR expansion only through explicit provider paths such as TSV/HOCR
  signal providers and a later PDF OCR provider, with OCRmyPDF/heavy providers
  kept opt-in
* main-repo OCR fixtures should stay tiny and license-clean; real-world OCR rows should live in quality-lab
* optional tesseract smoke should stay outside the default native quality gate
* OCR/Vision quality-lab artifact checks remain internal/dev-only and do not
  imply current product OCR support
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
