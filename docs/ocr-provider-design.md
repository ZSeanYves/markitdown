# OCR Provider Design

This document describes the OCR provider boundary for `markitdown-mb` and
records the current OCRmyPDF audit. It is intentionally design-first: the
repository currently implements explicit image OCR through `tesseract-cli`, but
does **not** implement OCRmyPDF execution as a product path yet.

Current boundary:

* default `normal` conversion remains native-text-first
* default `normal` conversion does **not** run OCR
* OCR stays explicit through the `ocr` CLI path or a future explicit provider
  selection path
* OCR output is an augmentation path, not native embedded text
* direct PDF OCR through OCRmyPDF remains audited/design-only for now

## Goals

* keep the default product path lightweight and deterministic
* make OCR explicit, explainable, and opt-in
* avoid bundling heavy OCR runtimes, Python stacks, or model files into the
  default build
* keep OCR engine metadata and provenance visible in debug/report output
* allow multiple OCR backends without changing the native conversion contract

## Non-goals

* hidden OCR fallback inside `normal`
* mandatory OCR runtime in the default install
* treating OCR text as if it were native embedded text
* bundling large OCR model assets into the repository
* implementing OCRmyPDF in the default gate before provenance semantics are
  settled

## Current Implementation Audit

Current CLI paths:

* `normal <input> [output]`
  * native path
  * no OCR by default
* `ocr <input> [output]`
  * explicit OCR path
  * today can route explicit image inputs through the optional
    `tesseract-cli` provider
  * direct PDF OCR remains a future provider route rather than the current
    image-ocr path

Current provider skeleton state:

* the repository carries a lightweight OCR provider skeleton in
  `convert/pdf/ocr/provider.mbt`
* the skeleton exposes:
  * static provider descriptors
  * a lazy explicit probe API
  * page-image OCR through `tesseract-cli`
  * a `noop` provider for report/test wiring
* the skeleton keeps `ocrmypdf-cli` and `paddleocr` as explicit future
  descriptors that currently fail closed with `unavailable`
* normal CLI does not probe providers and debug-only listing requires explicit
  `providers --probe`

Current result/model state:

* `OcrOptions` currently exposes:
  * `languages`
  * `page_range`
  * `output_text_only`
* `OcrPageResult` currently exposes:
  * `page_index`
  * `text`
  * `confidence`
  * `language`
  * `warnings`
* `OcrDocumentResult` currently exposes:
  * `provider`
  * `pages`
  * `warnings`

Current PDF-specific audit:

* PDF inspect/debug already surfaces:
  * `text_signal_level`
  * `image_only`
  * `ocr_recommended`
  * page/image/native-text object counts
* these diagnostics are report-only and do not trigger OCR
* there is also an older `convert/pdf/ocr/pdf_ocr.mbt` prototype that shells
  out to OCRmyPDF sidecar mode, but it is not the current product contract
  because it does not carry sufficient provenance, uses a simplistic temp-file
  policy, and would risk polluting the native PDF path if reused as-is

## Provider Interface

OCR should sit behind a provider interface so the CLI and converter layer do
not depend on a single engine.

Current interface shape:

```text
list_known_ocr_providers() -> Array[OcrProviderInfo]
probe_known_ocr_provider(name) -> OcrProviderInfo?
recognize_page_with_ocr_provider(name, page_index, page_image_path, options)
  -> Result[OcrPageResult, OcrProviderError]
recognize_pdf_with_ocr_provider(name, input_path, options)
  -> Result[OcrDocumentResult, OcrProviderError]
```

Current implementation status:

* descriptors exist for:
  * `noop`
  * `tesseract-cli`
  * `ocrmypdf-cli`
  * `paddleocr`
* known providers stay unprobed until explicit probe calls
* `tesseract-cli` implements:
  * explicit availability probing via `tesseract --version`
  * explicit page-image OCR via `tesseract <image> stdout -l <langs>`
* direct PDF OCR is intentionally still unimplemented in the provider layer

Design conclusion for this interface:

* keep the public OCR provider API stable **for now**
* do **not** implement OCRmyPDF against the current `OcrDocumentResult`
  contract until provenance gaps are addressed
* when OCRmyPDF is eventually implemented, extend the result model
  additively rather than replacing existing fields

Suggested future additive fields before OCRmyPDF lands:

```text
OcrPageProvenance?
  page_index
  text_source
  ocr_performed
  skipped_reason?
  native_text_present
  image_signal_present

OcrDocumentResult
  provider
  pages
  warnings
  provenance?            # additive
  output_pdf_path?       # additive
  sidecar_text_only?     # additive
```

## OCRmyPDF Audit: Fit For Explicit PDF OCR

OCRmyPDF is a good **candidate** for an explicit PDF OCR provider, but only
under a strict boundary.

Why it fits:

* it is PDF-specific rather than page-image-only
* it already models important mixed-document cases:
  * pages that already contain text
  * mixed born-digital + scanned PDFs
  * redoing existing OCR
* it supports sidecar text generation, including `--output-type none`, which is
  attractive for explicit text-only OCR workflows

Why it must stay optional:

* it is a heavier environment than `tesseract-cli` image OCR
* it depends on an external user-installed runtime and its own dependency stack
* it is not suitable for bundling into the default native product path
* it would otherwise blur the boundary between native PDF text extraction and
  OCR-augmented extraction

Recommendation:

* `ocrmypdf-cli` is appropriate as a **future explicit PDF OCR provider**
* it should remain:
  * external
  * user-installed
  * provider-selected
  * provenance-tagged
  * absent from the normal path

## OCRmyPDF Behavioral Boundaries

Official OCRmyPDF behavior is important to preserve in our design:

* by default, if a PDF appears to contain text, OCRmyPDF aborts rather than
  modifying it
* `--mode skip` / `--skip-text` copies text pages without OCR and OCRs only the
  pages that need it
* `--mode redo` / `--redo-ocr` attempts to replace existing OCR while
  preserving visible digital text
* `--mode force` / `--force-ocr` rasterizes everything and OCRs all pages

Design recommendation for `markitdown-mb`:

* if OCRmyPDF is implemented, the default explicit provider mode should be
  conservative mixed-PDF handling equivalent to `--mode skip`
* `redo` should remain a later explicit opt-in because it changes semantics for
  previously OCRed files
* `force` should remain a later explicit danger mode because it rasterizes
  visible text and interactive content

This keeps the first OCRmyPDF provider route aligned with repository policy:

* explicit only
* no silent rewriting of born-digital PDFs
* no default flattening/rasterization

## Sidecar Semantics And Provenance

OCRmyPDF sidecar text is **not** equivalent to “all text in the PDF”.

Official behavior matters here:

* the sidecar contains OCR text found by OCRmyPDF
* pages that already have text do not appear in the sidecar
* pages skipped by `--pages`, `--skip-big`, or OCR timeouts do not appear in
  the sidecar

Therefore:

* sidecar text must be treated as `ocr_sidecar_only`
* it must not be labeled `native_text`
* it must not be treated as a complete document-text replacement without
  additional provenance-aware merging

Recommended provenance vocabulary for a future OCRmyPDF provider:

* `native_embedded_text`
* `ocr_sidecar_text`
* `mixed_native_and_ocr`
* `skipped_existing_text`
* `skipped_timeout`
* `skipped_big`
* `skipped_page_selection`
* `ocr_empty`

Recommended document-level metadata/report fields:

* `ocr_used = true`
* `ocr_provider = "ocrmypdf-cli"`
* `ocr_mode = "skip" | "redo" | "force"`
* `ocr_output_type = "none" | "pdf" | "pdfa" | "auto"`
* `ocr_sidecar_only = true|false`
* `ocr_languages = [...]`
* `ocr_page_count`
* `native_text_page_count`
* `skipped_existing_text_page_count`
* `skipped_timeout_page_count`
* `skipped_big_page_count`
* `stderr_summary`
* `provider_exit_code`

Design conclusion:

* do not merge OCRmyPDF sidecar text into the native PDF text path implicitly
* if a future explicit CLI wants “OCR text only”, that is fine, but it must say
  so explicitly in metadata/provenance
* if a future explicit CLI wants “full PDF text with OCR augmentation”, that
  must be a separate provenance-aware merge design, not an accidental reuse of
  sidecar output

## Output Strategy

Recommended future provider behavior for explicit PDF OCR:

Initial explicit OCR text route:

* call OCRmyPDF with sidecar enabled
* prefer `--output-type none` when the user only wants OCR text
* treat the sidecar as OCR-only text
* lower that text through an explicit OCR text-to-IR path only

Future searchable-PDF route:

* if the product later wants to keep OCRmyPDF output PDFs, make that a separate
  explicit artifact path
* do not implicitly mix “generate searchable PDF” with “emit Markdown” in the
  first provider rollout

This keeps the first OCRmyPDF provider scope narrow and auditable.

## Temporary Files And Cleanup

The older in-tree OCRmyPDF prototype used an ad-hoc `/tmp` sidecar filename.
That is not a good long-term contract.

If OCRmyPDF lands as a provider, it should:

* create a unique per-invocation temp directory
* place sidecar and any retained intermediate files under that directory
* clean the directory on both success and failure by default
* expose retained temp directories only under an explicit debug flag
* never rely on a fixed `/tmp/markitdown_ocr_sidecar_<...>` naming scheme

Recommended cleanup policy:

* default: remove sidecar and temp dir after result collection
* explicit debug path: keep temp dir and surface its path in stderr/report
* never leave sidecar artifacts in the repository tree or sample fixtures

## Process, Exit Code, And stderr Handling

OCRmyPDF is an external process and must be treated like one:

* capture stdout and stderr fully
* map exit codes into provider-level errors
* keep stderr summaries in warnings/provenance rather than treating stderr as a
  success signal

Important documented exit-code cases include:

* missing dependency
* already contains text
* child-process failure
* encrypted PDF
* invalid configuration

Design recommendation:

* map “already has text” to an explicit provider-level boundary rather than a
  generic recognition failure
* map missing dependency to `Unavailable`
* map child process failures and malformed-PDF failures to
  `RecognitionFailed`/`NotImplemented` style explicit errors with preserved
  provider stderr context

## Language Mapping

OCRmyPDF uses Tesseract language packs and accepts:

* `-l eng`
* `-l eng+fra`
* repeated `-l`

Design recommendation:

* continue using `OcrOptions.languages : Array[String]`
* normalize to joined `eng+fra` form for CLI parity with the current
  `tesseract-cli` provider path
* keep the repository default conservative:
  * if no language is set, assume OCRmyPDF/Tesseract default behavior
  * do not auto-detect or guess languages in `markitdown-mb`

## Security And Command Discovery

OCRmyPDF must remain an external optional command, not a bundled runtime.

Recommended discovery rules:

* do not scan arbitrary directories for OCRmyPDF
* do not execute shell strings like `sh -c "ocrmypdf ..."`
* resolve only:
  * an explicit provider command-path override env var, or
  * a bare `ocrmypdf` executable on `PATH`
* keep probing explicit and lazy

This mirrors the current repository direction for OCR providers:

* normal path: no probe
* debug providers: explicit listing, optional explicit probe
* OCR command path: explicit provider selection only

## Licensing And Dependency Policy

OCRmyPDF is MPL-2.0 and should be treated as:

* external
* user-installed
* not vendored into this repository
* not a bundled runtime dependency of the native default package

No models or OCRmyPDF runtime dependencies should be downloaded or shipped by
default as part of `markitdown-mb`.

## Recommended Rollout

Near term:

* keep OCR explicit
* keep direct PDF OCR unimplemented in the provider runtime
* document OCRmyPDF sidecar/provenance semantics before any implementation
* keep provider descriptors/probe surfaces lightweight and lazy

Mid term:

* add additive provenance fields to the OCR result contract
* add an explicit OCRmyPDF provider implementation only after temp-file,
  exit-code, and sidecar semantics are settled
* keep the first OCRmyPDF execution path scoped to explicit PDF OCR only

Long term:

* support richer explicit OCR PDF artifacts if needed
* consider provenance-aware native+OCR text merge only as a separate, explicit
  design
* support plugin/external-provider registration without changing native mode

## Explicit Non-recommendations

Do not:

* run OCR silently in `normal`
* probe OCRmyPDF in the normal path
* treat OCRmyPDF sidecar text as embedded/native PDF text
* wire OCRmyPDF into the default native quality gate
* ship Python/OCR runtimes in the default build
* implement direct PDF OCR before provenance is explicit and auditable
