# OCR Provider Design

This document describes the planned OCR provider route for `markitdown-mb`.

Current boundary:

* default `normal` conversion remains native-text-first
* default `normal` conversion does **not** run OCR
* OCR stays explicit through the `ocr` CLI path or a future explicit provider
  selection path
* OCR output is an augmentation path, not native-text output

## Goals

* keep the default product path lightweight and deterministic
* make OCR explicit, explainable, and opt-in
* avoid bundling heavy OCR runtimes or model files into the default build
* keep OCR engine metadata visible in debug/report output
* allow multiple OCR backends without changing the native conversion contract

## Non-goals

* hidden OCR fallback inside `normal`
* mandatory OCR runtime in the default install
* treating OCR text as if it were native embedded text
* bundling large OCR model assets into the repository

## Current state

Current CLI paths:

* `normal <input> [output]`
  * native path
  * no OCR by default
* `ocr <input> [output]`
  * explicit OCR path
  * today backed by the existing OCR pipeline and external runtime probing

Current provider skeleton state:

* the repository now carries a lightweight OCR provider skeleton
* the skeleton exposes:
  * static provider descriptors
  * a lazy explicit probe API
  * a `noop` provider for report/test wiring
* the skeleton does **not** execute OCR engines yet
* no OCR runtime is bundled into the default build

Current repository policy:

* scan-only/image-only PDFs are not native-text failures
* native/report tooling may flag OCR-needed candidates
* OCR quality work should remain separate from the native quality gate

## Provider interface

OCR should sit behind a provider interface so the CLI and converter layer do
not depend on a single engine.

Suggested interface shape:

```text
OcrProvider
  name() -> String
  version() -> String?
  license() -> String?
  available() -> Bool
  supported_languages() -> Array[String]
  recognize_page_image(page_image, options) -> Result[OcrPageResult, OcrError]
  recognize_pdf(path, options) -> Result[OcrDocumentResult, OcrError]
```

Current implementation status:

* provider descriptors exist for:
  * `noop`
  * `tesseract-cli`
  * `ocrmypdf-cli`
  * `paddleocr`
* known providers stay unprobed until explicit probe calls
* `tesseract-cli` now implements:
  * explicit availability probing via `tesseract --version`
  * explicit page-image OCR via `tesseract <image> stdout -l <langs>`
* `ocrmypdf-cli` and `paddleocr` still fail closed with `unavailable`
* debug-only provider listing now exists, and `--probe` is required before any
  availability check runs

Suggested result shapes:

```text
OcrPageResult
  page_index
  text
  blocks?
  confidence?
  language?
  engine
  source_refs
  warnings

OcrDocumentResult
  pages
  engine
  language?
  warnings
```

## OCR metadata/report contract

When OCR is used, report/debug/metadata should make that explicit.

Suggested flags:

* `text_source = ocr`
* `ocr_used = true`
* `ocr_engine = <provider name>`
* `ocr_language = <best effort>`

This should never be implied in the default native path.

## Availability rules

Provider availability should stay lazy:

* do not probe heavy OCR runtimes during `normal` startup
* do not scan model directories on every CLI run
* only resolve OCR provider availability when the user explicitly requests OCR
  or an OCR-specific debug/bench flow

Current skeleton follows that rule:

* listing known providers is pure/static
* normal CLI does not probe provider availability
* the skeleton does not scan model directories
* the skeleton does not spawn subprocesses unless an explicit probe API is
  called

## Candidate providers

### Tesseract

* license: Apache-2.0
* likely shape: external CLI/provider
* strengths:
  * common packaging
  * multi-language
  * easier to expose as optional dependency
* current implementation:
  * explicit provider only
  * page-image OCR only
  * requires user-installed `tesseract` plus language data
* recommendation:
  * strong candidate for a light explicit external provider

### OCRmyPDF

* license: MPL-2.0
* likely shape: PDF-wrapper provider
* strengths:
  * PDF-specific workflow
  * sidecar-friendly behavior
* tradeoffs:
  * heavier environment
  * not a good default dependency
* recommendation:
  * optional provider only

### PaddleOCR / PP-Structure

* license: Apache-2.0 for the codebase, but model/runtime review still matters
* strengths:
  * OCR + structure/layout/table potential
* tradeoffs:
  * heavier runtime and model footprint
  * should stay outside default package/runtime
* recommendation:
  * heavy optional provider/plugin, not a normal-path dependency

## Recommended rollout

Near term:

* keep OCR explicit
* improve report-only OCR-needed detection
* document provider contract
* keep the provider skeleton runtime-free by default

Mid term:

* refine provider registry / availability probe reporting
* improve `ocr` CLI error reporting and engine reporting
* optionally route explicit OCR flows through provider selection

Long term:

* support plugin/external-provider registration
* allow engine-specific OCR + structure backends without changing native mode

## Explicit non-recommendations

Do not:

* run OCR silently in `normal`
* ship heavy OCR runtimes in the default build
* mix OCR output into native-text metrics
* claim OCR support as part of the native default PDF contract
