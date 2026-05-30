# PDF lower-layer parser

`doc_parse/pdf` is the native PDF structural recovery package used by the normal PDF path in `markitdown-mb`.

Its job is to turn rendering-oriented PDF content into a parser-facing document model. It does not emit final Markdown, does not own final IR shaping, and does not implement OCR. Upper layers such as `convert/pdf` decide how the recovered model becomes Markdown.

Foundation direction:

- `doc_parse/pdf` should keep evolving as a reusable native text-PDF parsing
  substrate
- `convert/pdf` is an important consumer, but it is not the design center of
  the lower layer
- publishable-quality hardening here should prioritize parser/model/debug
  boundaries, structured inspect/report surfaces, and fail-closed behavior
  over broader semantic ambition

## Candidate Status

Current status:

- `doc_parse/pdf` is treated as a native text-PDF foundation candidate within
  the current repository scope
- this candidate status is for the native text-PDF lower layer only
- it does not claim scanned-PDF support, OCR default support, full PDF spec
  support, or full visual-layout/tagged-PDF semantics

Current package split:

- there is no single root `doc_parse/pdf` package facade
- the recommended package-facing entrypoint is `doc_parse/pdf/api`
- current delivery remains importable subpackages under
  `ZSeanYves/markitdown`, not a separately split MoonBit module
- `model`, `raw`, and `text` remain important lower-layer packages, but they
  are not the primary stable candidate facade for new consumers

## Scope

`doc_parse/pdf` currently owns:

- opening text-based PDFs through the vendored `mbtpdf` backend
- extracting page text, images, page geometry, and low-level source references
- normalizing raw extracted content into chars, spans, lines, blocks, and pages
- exposing a stable `PdfDocumentModel` to higher converter layers
- exposing structured inspect/report data plus debug/inspection strings for the
  recovered model

`doc_parse/pdf` does not own:

- final Markdown formatting
- final converter IR decisions
- OCR
- annotation/link/table semantic recovery
- final image-caption pairing decisions
- Markdown link emission for annotations/links
- browser-like visual layout reconstruction

Text-normalization boundary:

- `doc_parse/pdf` may use the shared `core/text_normalization.mbt` facade for
  low-risk extracted-text cleanup before higher PDF heuristics run.
- That shared cleanup is now rule-driven and profile/policy-gated on the core
  side; `doc_parse/pdf` consumes it as a pure-string cleanup substrate rather
  than re-implementing parallel post-text replacement chains.
- It does not own project-wide canonical normalization policy and should not
  push shared cross-format cleanup rules down into
  `doc_parse/pdf/vendor/mbtpdf`.
- Contextual PDF repair such as span glue, line-wrap hyphen repair, page-edge
  artifact handling, and other geometry/source-ref heuristics stays local to
  `doc_parse/pdf` and is not a core text-normalization responsibility.

## Vendored Backend Boundary

The only backend currently wired into `doc_parse/pdf` is vendored `mbtpdf`.

The backend boundary is intentionally narrow:

- `raw/mbtpdf_*_adapter.mbt` imports and consumes `mbtpdf` types.
- `raw/pdf_raw_types.mbt` exposes project-owned raw structs, not `mbtpdf` objects.
- `text`, `model`, and `api` consume project-owned raw/model types.
- `convert/pdf` consumes `pdf/api` output and should not depend on `mbtpdf`.

Recent backend work:

- V0: `mbtpdf` was vendored and connected as the PDF backend.
- V1: `LocatedOp` and `parse_operators_with_source` were added so operators can carry source references.
- V2.0: raw/model pages gained media box, crop box, rotation, raw page refs, and raw content stream refs.
- V2.1: vendored `Page.cropbox` now supports inherited `/CropBox`.

The public vendor API changed in V2.1 because `doc_parse/pdf/vendor/mbtpdf/document/pdfpage.Page` now includes:

```moonbit
cropbox : PdfObject?
```

This is intentionally contained inside the vendored backend and raw adapter boundary.

## Pipeline

The normal native pipeline is:

```text
mbtpdf
-> raw
-> chars
-> spans
-> lines
-> blocks
-> PdfDocumentModel
-> convert/pdf
```

Layer responsibilities:

- `raw`: factual backend extraction and backend-to-project type conversion.
- `text`: char/span/line/block reconstruction and text recovery heuristics.
- `model`: stable document, page, text, image, geometry, and source-reference structs.
- `api`: package entry points, backend selection, model building, and debug summaries.
- `debug`: there is no separate `debug` package; debug/inspection helpers currently live in `api` and selected pipeline files.

## Raw Layer

`raw` is the only layer that should directly understand `mbtpdf`.

Primary output:

- `RawPdfDocumentExtract`
- `RawPdfPageExtract`
- `RawTextOp`
- `RawImageInfo`

Current page-level raw fields include:

- `page_index`
- `raw_page_ref`
- `media_box`
- `crop_box`
- `rotation`
- `raw_content_stream_refs`
- typed raw inspect issues
- text ops
- images
- annotations

The adapter resolves inherited page geometry through `mbtpdf` page-tree reading. `crop_box` is parsed from `Page.cropbox`; malformed rectangles fall back to `None`.

Pass 3 typed raw issue starter:

- `RawPdfDocumentExtract` and `RawPdfPageExtract` now carry additive
  `issues : Array[PdfRawIssue]`
- raw issues are report-only inspect signal and do not change the default
  parse/build/convert path
- currently real raw issue kinds are:
  - `EncryptedDocument`
  - `AnnotationParseWarning`
  - `ImageParseWarning`
- `UnsupportedObjectStream` is now wired into the raw/report/classifier
  pipeline as a typed slot, but current vendored backend exposure does not yet
  surface a live object-stream marker beyond this starter plumbing

## Text Layer

`text` turns raw page content into progressively richer textual structure:

- `pdf_text_chars.mbt`: raw text ops to character records.
- `pdf_text_spans.mbt`: character grouping.
- `pdf_text_lines.mbt`: line construction, normalization, merging, and page-line filtering.
- `pdf_text_blocks.mbt`: block construction.
- `pdf_text_normalization.mbt`, `unicode_compat.mbt`, and `pdf_text_rules.mbt`: normalization and recovery heuristics.

This layer is heuristic-heavy by design. Rules should stay conservative, explainable, and regression-backed.

## Model Layer

`model` owns the stable internal representation exposed to the rest of the repository.

Important model groups:

- geometry: `PdfPoint`, `PdfRect`, page boxes
- text: chars, spans, lines, blocks
- image metadata and payloads
- page/document containers
- source references

`PdfPageModel` currently carries page geometry and provenance data:

- `boxes.media_box`
- `boxes.crop_box`
- `rotation`
- `raw_content_stream_refs`

`raw_page_ref` currently remains in the raw layer and is surfaced through debug/inspection output, not through `PdfPageModel`.

These fields are parser-facing metadata. They are not rendered directly to Markdown by `doc_parse/pdf`.

## API Layer

`api` is the public entry point for the package.

Main APIs:

- `default_pdf_config`
- `extract_document_model`
- `extract_document_summary`
- `extract_document_inspect_report`
- `inspect_pdf_document`
- `inspect_pdf_page`
- `classify_pdf_inspect_issue`
- `classify_pdf_error_with_issues`
- `extract_document_block_debug`
- `extract_document_inspect_dump`
- `classify_pdf_error`

Stable candidate API:

- `extract_document_model`
- `extract_document_summary`
- `extract_document_inspect_report`
- `inspect_pdf_document`
- `inspect_pdf_page`
- `classify_pdf_error`
- `classify_pdf_inspect_issue`
- `classify_pdf_error_with_issues`

These are the recommended package-facing APIs for external MoonBit consumers.
New tooling should start here rather than depending directly on raw adapter or
text-reconstruction internals.

Structured inspect/report types:

- `PdfDocumentInspectReport`
- `PdfPageInspectInfo`
- `PdfInspectIssue`
- `PdfInspectIssueKind`
- `PdfInspectIssueSource`
- `PdfInspectSeverity`
- `PdfErrorInfo`
- `PdfErrorKind`

Debug / inspect convenience API:

- `extract_document_block_debug`
- `extract_document_inspect_dump`

These APIs stay public because they are useful for CLI debug and human
inspection, but they should not be treated as the main machine-readable
contract.

`extract_document_model` runs the full native pipeline and returns `PdfDocumentModel`.

`extract_document_summary` returns a compact human-readable summary including document version, page count, and top-level object totals.

`extract_document_inspect_report` returns a structured `PdfDocumentInspectReport`. It exposes page counts, success/failure counts, document flags, metadata, text/image/annotation/vector/form totals, page-level signal summaries, and non-fatal inspect issues. This is the primary machine-readable inspect contract for PDF package users.

Current Pass 3 inventory/report additions include:

- document-level `text_page_count`, `empty_page_count`, and
  `low_signal_page_count`
- document-level `has_image_signal` and `has_annotation_signal`
- document-level `total_link_annotation_count` and `total_source_ref_count`
- document-level `page_failure_count`
- document-level `unsupported_feature_count`
- document-level `raw_issue_count` and `model_issue_count`
- page-level `effective_width` / `effective_height`
- page-level `link_annotation_count`, `source_ref_count`, `raw_issue_count`,
  `model_issue_count`, and `issue_count`

`extract_document_block_debug` returns a textual inspection dump that joins raw-page provenance with model-page structure. It includes document flags and totals, per-page geometry and raw refs, content stream refs, text block/line/span counts, image summaries, annotation summaries, and block/line details. It now reuses the structured inspect report for summary totals and page quality signals, but it remains a diagnosis string rather than a stable Markdown or IR format. Upper `convert/pdf` pipeline debug may further retain convert-stage image provenance and page annotation passthrough on top of this, but those remain inspect/debug data rather than stable Markdown or IR semantics.

`classify_pdf_error` returns a structured `PdfErrorInfo` so callers can
separate adapter/build/unsupported failures from more specific detail kinds
such as encrypted, malformed, unsupported object stream, unsupported filter, or
low-signal cases.

`classify_pdf_inspect_issue` and `classify_pdf_error_with_issues` let audit
consumers prefer typed inspect issues when the lower layer already exposed a
stronger signal than a generic top-level error variant.

Error classifier mapping kinds:

- `DirectVariant`
- `TypedIssue`
- `BestEffortMessage`

Current typed signals:

- `EncryptedDocument`
- `AnnotationParseWarning`
- `ImageParseWarning`
- `PartialPageFailure`
- `EmptyPage`
- `LowSignalPage`
- `EmptyExtraction`
- `LowSignalExtraction`

Reserved / future typed signals:

- `UnsupportedObjectStream`
- `UnsupportedFilter`
- `MalformedContentStream`
- `MissingFontEncoding`
- `BadToUnicode`
- `Malformed`
- deeper page-local partial build failure taxonomy

Classifier status:

- direct top-level mapping today:
  - `AdapterFailed`
  - `BuildFailed`
  - `Unsupported`
- typed issue mapping today:
  - the current typed signals listed above
- best-effort message mapping still used today for:
  - `Encrypted`
  - `Malformed`
  - `UnsupportedFilter`
  - `MalformedContentStream`
  - `MissingFontEncoding`
  - `BadToUnicode`
  - `UnsupportedObjectStream` when no typed raw issue is available

Any kind that still depends on message-level inference should be treated as
best-effort rather than as fully source-mapped parser truth.

Compatibility surface:

- `PdfError` remains the top-level failure type returned by the existing path-based APIs
- `PdfDocumentModel` remains the main converter-facing lower-layer model
- the lower-layer model fields continue to be the compatibility surface that `convert/pdf` uses directly
- `RawPdfDocumentExtract`, `RawPdfPageExtract`, and related raw structs are
  also part of the current compatibility surface for repository tests and
  lower-layer inspection

Internal exposed surface:

- `raw/mbtpdf_*_adapter.mbt` remains the vendored-backend integration detail
- `text/*` reconstruction helpers and predicates remain implementation-heavy
  internals even though selected values are still exported today
- `model/*` bbox/source-ref counters and glue helpers are useful lower-layer
  utilities, but they are closer to assembly helpers than to the primary
  stable facade

Versioning / API stability note:

- stable candidate facade means the `api` package entrypoints above are the
  preferred surface to keep additive and steady
- compatibility surfaces remain public because `convert/pdf`, CLI debug, and
  lower-layer tests still depend on them
- future independent release work may encapsulate more raw/model/text details,
  but this candidate pass does not tighten field visibility or break existing
  repository consumers

Candidate boundary reminders:

- no full visual layout engine
- no full tagged-PDF semantic extraction
- no OCR default fallback
- no scanned-PDF support by default
- no full PDF spec support claim
- no complete recovery from malformed PDFs

Inspect issue model:

- `PdfInspectIssue` is a report-only audit surface.
- It does not change default parse or conversion behavior.
- inspect issues now record `source = Raw | Model`, optional page/object/source
  provenance, and deterministic per-page/document ordering.
- empty/low-signal findings remain inspect/report warnings or errors, not new
  hard parser failures.
- document-level issues currently cover:
  - encrypted-document marker
  - partial-page-failure marker
  - empty-document marker
  - low-signal-document marker
- page-level issues currently cover:
  - empty-page marker
  - low-signal-page marker
  - raw annotation-parse warning marker
  - raw image-parse warning marker

Annotation/link boundary:

- `doc_parse/pdf` reports raw annotation and link-like annotation counts through
  inspect/inventory surfaces.
- It still does not own final annotation-to-Markdown link emission policy.

## Current Limits

Known limits:

- no full multi-column reading order engine
- no table semantic reconstruction
- no annotation/link semantic model
- no final image-caption pairing semantics in this layer
- no OCR in the native path
- no full vector/graphics semantic recovery
- no browser-like layout engine
- image extraction exists, but image semantics remain limited
- many line/block decisions remain heuristic and sample-regression driven

## Package Audit Notes

Current responsibilities are mostly separated:

- `raw` is the backend adapter boundary.
- `model` is type ownership.
- `text` is reconstruction logic.
- `api` is orchestration and public entry.
- debug output is available through API helpers and gated internal debug functions.

Recent cleanup:

- R1 split the raw adapter into `mbtpdf_text_adapter.mbt`, `mbtpdf_page_adapter.mbt`, `mbtpdf_image_adapter.mbt`, `mbtpdf_annotation_adapter.mbt`, and `mbtpdf_object_helpers.mbt`.

Files that are still large enough to consider splitting later:

- `raw/mbtpdf_text_adapter.mbt`: text-state and text-op logic are still concentrated in one file.
- `text/pdf_text_rules.mbt`: many unrelated recovery predicates live together.
- `text/pdf_text_normalization.mbt`: normalization and hardwrap behavior could be grouped by concern.
- `api/test/pdf_api_test.mbt`: broad integration coverage in one test file.

Suggested future splits, without changing behavior now:

- `raw/mbtpdf_text_ops.mbt`
- `text/rules_heading.mbt`
- `text/rules_hardwrap.mbt`
- `text/rules_noise.mbt`

## Tests

Useful verification commands:

```sh
moon check
moon test
./samples/check.sh
```

Current sample tests are expected to show no Markdown output changes for C0 documentation/package cleanup.

## ToUnicode Level 1

Current native text extraction now includes a Level 1 `/ToUnicode` CMap path
in the vendored `mbtpdf` layer.

What is supported today:

- `begincodespacerange`
- `beginbfchar`
- `beginbfrange` sequential form when the destination is a single UTF-16BE
  codepoint
- `beginbfrange` array form
- multi-byte source-code greedy matching using the declared code-space lengths
- UTF-16BE destination decoding, including surrogate-pair destinations
- conservative Type0/CIDFont positive paths when the source PDF provides a
  usable `/ToUnicode` map

What remains out of scope:

- full predefined CMap coverage beyond the small existing backend subset
- embedded font `cmap` fallback
- GBK / GB18030 byte-decoding fallback
- broad no-`/ToUnicode` CJK rescue

Known external boundary:

- the local external row `pdf_cjk_text_pdfjs_simfang_variant` remains a
  `known_bad` because it is a raw-GBK, no-`/ToUnicode` simple-font case rather
  than a missing `/ToUnicode` parser case
- the local external row
  `pdf_type0_identity_no_tounicode_pdfjs_arial_unicode_en_cidfont` remains a
  `known_bad` because it is a `Type0 / CIDFontType2 / Identity-H` sample with
  no `/ToUnicode`, a `CIDToGIDMap` stream, and an embedded subset `FontFile2`
  that does not carry a usable `cmap` table for a narrow fallback

Current support matrix shorthand:

- simple font + `/ToUnicode`: supported on the current native text path
- Type0/CIDFont + `/ToUnicode`: supported conservatively when the map is
  usable; current local Arabic positive rows exercise this path
- Type0/CIDFont + bad `/ToUnicode`: retained boundary; replacement characters
  may still be the correct outcome when the map itself is low-value
- Type0/CIDFont + `/Identity-H` + no `/ToUnicode`: not a reliable extraction
  contract today
- simple font + raw GBK + no `/ToUnicode`: separate unsupported boundary; no
  GBK/GB18030 fallback is active in the default native path
- inspect/report already exposes low-text/image-only signal such as
  `has_text_signal`, `has_image_signal`, low-signal counts, and
  `native_signal_empty`; report-only diagnostics now also summarize
  `text_signal_level`, `image_only`, `ocr_recommended`, and native
  char/image counts; the default native parse path still does not OCR

## Performance Note

Current performance note:

* native text extraction and lower-layer model building should be measured
  separately from converter-side heading/table/caption heuristics
* this package does not claim sub-10ms behavior for all PDF rows, and current
  public benchmark numbers remain repository-level product timings first
